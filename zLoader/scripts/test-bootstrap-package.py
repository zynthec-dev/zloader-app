"""Verify real external/full IPA layout and dormant-provider identity/version integrity."""
import hashlib
import io
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[2]
for internal in [True]:
    ipa = root / 'outputs' / 'zLoader-resignable.ipa'
    with zipfile.ZipFile(ipa) as archive:
        assert archive.testzip() is None
        assert any('/PlugIns/zLoaderTunnel.appex/' in name for name in archive.namelist()) == internal
        info = plistlib.loads(archive.read('Payload/zLoader.app/Info.plist'))
        assert 'Payload/zLoader.app/PlugIns/zLoaderWidget.appex/Info.plist' in archive.namelist()
        if internal:
            data = archive.read('Payload/zLoader.app/zLoaderTunnelPayload.zip')
            manifest = plistlib.loads(archive.read('Payload/zLoader.app/zLoaderTunnelPayload.plist'))
            assert manifest['sha256'] == hashlib.sha256(data).hexdigest()
            assert manifest['version'] == info['CFBundleShortVersionString']
            assert manifest['build'] == info['CFBundleVersion']
            with zipfile.ZipFile(io.BytesIO(data)) as provider:
                assert provider.testzip() is None
                assert not any(name.endswith('embedded.mobileprovision') for name in provider.namelist())
                provider_info = plistlib.loads(provider.read('zLoaderTunnel.appex/Info.plist'))
                assert provider_info['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.networkextension.packet-tunnel'
                assert provider_info['CFBundleShortVersionString'] == manifest['version']
                assert provider_info['CFBundleVersion'] == manifest['build']
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(['ditto', '-x', '-k', str(ipa), folder], check=True)
        host = Path(folder) / 'Payload/zLoader.app'
        declared = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', '-', '--xml', str(host)], stderr=subprocess.DEVNULL))
        assert ('com.apple.developer.networking.networkextension' in declared) == internal
        assert declared['com.apple.security.application-groups'] == ['group.com.zynthec.zLoader']
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(host)], check=True, capture_output=True)
print('PASS single IPA contains installed provider and recovery payload, version/build/hash integrity, profile-free archive and ad-hoc entitlement contract')
