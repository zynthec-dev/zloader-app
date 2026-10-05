"""Package without fake-signing or claiming entitlement authorization."""
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import zipfile
import subprocess

root = Path(__file__).resolve().parents[2]
app = root / '.build/Device/Build/Products/Release-iphoneos/zLoader.app'
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleName'] == 'zLoader'
assert info['CFBundleIdentifier'] == 'com.zynthec.zLoader'
tunnel = app / 'PlugIns/zLoaderTunnel.appex'
ext = plistlib.loads((tunnel / 'Info.plist').read_bytes())
assert ext['CFBundleIdentifier'] == info['CFBundleIdentifier'] + '.Tunnel'
assert ext['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.networkextension.packet-tunnel'
for name in ['SideStore-License', 'LocalDevVPN-License', 'LocalDevVPN-License-old']:
    assert (app / (name + '.md')).stat().st_size > 100
out = root / 'outputs'
out.mkdir(exist_ok=True)
staging = out / 'unsigned-staging'
if staging.exists():
    shutil.rmtree(staging)
shutil.copytree(app, staging / 'Payload/zLoader.app', symlinks=True)
# Remove inherited vendor signatures as well as host/extension signatures.
# This is a fully unsigned artifact; no capability requests are fabricated.
macho_magic = {bytes.fromhex(value) for value in
               ["feedface", "cefaedfe", "feedfacf", "cffaedfe", "cafebabe", "bebafeca", "cafebabf", "bfbafeca"]}
for path in (staging / 'Payload').rglob('*'):
    if path.is_file() and not path.is_symlink():
        with path.open('rb') as handle:
            is_macho = handle.read(4) in macho_magic
        if is_macho:
            signed = subprocess.run(['codesign', '-d', str(path)], capture_output=True)
            if signed.returncode == 0:
                subprocess.run(['codesign', '--remove-signature', str(path)], check=True)
            assert subprocess.run(['codesign', '-d', str(path)], capture_output=True).returncode != 0
for path in list((staging / 'Payload').rglob('_CodeSignature')):
    if path.is_dir():
        shutil.rmtree(path)
for path in (staging / 'Payload').rglob('embedded.mobileprovision'):
    path.unlink()
ipa = out / 'zLoader-unsigned.ipa'
# ditto preserves bundle links/permissions, unlike a naive Python ZIP writer.
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent',
                str(staging / 'Payload'), str(ipa)], check=True)
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
    assert 'Payload/zLoader.app/PlugIns/zLoaderTunnel.appex/Info.plist' in archive.namelist()
result = {'artifact': ipa.name, 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
          'bundleIdentifier': info['CFBundleIdentifier'], 'tunnelIdentifier': ext['CFBundleIdentifier'],
          'signing': 'unsigned; valid Network Extension provisioning for host and provider required'}
(out / 'zLoader-unsigned.json').write_text(json.dumps(result, indent=2) + '\n')
shutil.rmtree(staging)
print(json.dumps(result, indent=2))
