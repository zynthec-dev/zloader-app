#!/usr/bin/env python3
"""Real TLS, token isolation, range streaming and shutdown on local Wi-Fi."""
import http.client
import json
import pathlib
import plistlib
import ssl
import subprocess
import tempfile
import time
import urllib.parse

binary = pathlib.Path('.build/LANInstaller/server-fixture').resolve()
with tempfile.TemporaryDirectory(prefix='zloader-lan-test-') as tmp:
    folder = pathlib.Path(tmp)
    content = bytes(range(256)) * 16385
    (folder / 'fixture.ipa').write_bytes(content)
    process = subprocess.Popen([str(binary), tmp], stdin=subprocess.PIPE, text=True)
    try:
        deadline = time.monotonic() + 20
        while True:
            if process.poll() is not None:
                raise RuntimeError('Fixture server exited before becoming ready')
            try:
                status = json.loads((folder / 'status.json').read_text())
                if status['error']:
                    raise RuntimeError(status['error'])
                if status['url']:
                    break
            except FileNotFoundError:
                pass
            if time.monotonic() > deadline:
                raise TimeoutError('Fixture server not ready')
            time.sleep(0.05)
        base = urllib.parse.urlsplit(status['url'])
        trust = ssl.create_default_context(cafile=str(folder / 'ca.pem'))

        def request(path, method='GET', headers=None):
            connection = http.client.HTTPSConnection(base.hostname, base.port, context=trust, timeout=15)
            try:
                connection.request(method, path, headers=headers or {})
                response = connection.getresponse()
                data = response.read()
                return response.status, dict(response.getheaders()), data
            finally:
                connection.close()

        assert request('/unshared/app.ipa')[0] == 404
        code, headers, page = request(base.path)
        assert code == 200 and b'itms-services://' in page
        code, headers, manifest = request(base.path + 'manifest.plist')
        assert code == 200
        assert plistlib.loads(manifest)['items'][0]['metadata']['bundle-version'] == '42'
        code, headers, data = request(base.path + 'app.ipa', headers={'Range': 'bytes=123-262400'})
        assert code == 206 and data == content[123:262401]
        assert headers['Content-Range'] == f'bytes 123-262400/{len(content)}'
        assert not json.loads((folder / 'status.json').read_text())['complete']
        code, headers, data = request(base.path + 'app.ipa', 'HEAD')
        assert code == 200 and not data and int(headers['Content-Length']) == len(content)
        assert request(base.path + 'app.ipa', headers={'Range': 'bytes=99999999-'})[0] == 416
        code, headers, data = request(base.path + 'app.ipa')
        assert code == 200 and data == content
        assert json.loads((folder / 'status.json').read_text())['complete']
        process.stdin.write('stop\n')
        process.stdin.flush()
        assert process.wait(timeout=10) == 0
        assert not json.loads((folder / 'status.json').read_text())['url']
        try:
            request(base.path)
        except OSError:
            pass
        else:
            raise AssertionError('Server still reachable after stop')
        print('PASS real TLS trust, token isolation, manifest, byte-range/HEAD, full IPA streaming and listener shutdown')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
