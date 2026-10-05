"""Package without fake-signing or claiming entitlement authorization."""
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import zipfile

root = Path(__file__).resolve().parents[2]
app = root / '.build/Device/Build/Products/Release-iphoneos/zLoader.app'
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleName'] == 'zLoader'
assert info['CFBundleIdentifier'] == 'com.zynthec.zLoader'
tunnel = app / 'PlugIns/ZLoaderTunnel.appex'
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
ipa = out / 'zLoader-unsigned.ipa'
# ditto preserves bundle links/permissions, unlike a naive Python ZIP writer.
import subprocess
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent',
                str(staging / 'Payload'), str(ipa)], check=True)
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
    assert 'Payload/zLoader.app/PlugIns/ZLoaderTunnel.appex/Info.plist' in archive.namelist()
result = {'artifact': ipa.name, 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
          'bundleIdentifier': info['CFBundleIdentifier'], 'tunnelIdentifier': ext['CFBundleIdentifier'],
          'signing': 'unsigned; valid Network Extension provisioning for host and provider required'}
(out / 'zLoader-unsigned.json').write_text(json.dumps(result, indent=2) + '\n')
shutil.rmtree(staging)
print(json.dumps(result, indent=2))
