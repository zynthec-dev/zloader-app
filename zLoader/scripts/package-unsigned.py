"""Package without fake-signing or claiming entitlement authorization."""
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import zipfile
import subprocess
import runpy
import argparse

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--internal', action='store_true')
args = parser.parse_args()
app = root / '.build/Device/Build/Products/Release-iphoneos/zLoader.app'
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleName'] == 'zLoader'
assert info['CFBundleIdentifier'] == 'com.zynthec.zLoader'
assert (app / 'PlugIns/zLoaderTunnel.appex').is_dir()
for name in ['SideStore-License', 'LocalDevVPN-License', 'LocalDevVPN-License-old']:
    assert (app / (name + '.md')).stat().st_size > 100
out = root / 'outputs'
out.mkdir(exist_ok=True)
staging = out / 'unsigned-staging'
if staging.exists():
    shutil.rmtree(staging)
shutil.copytree(app, staging / 'Payload/zLoader.app', symlinks=True)
if not args.internal:
    runpy.run_path(str(root / 'zLoader/scripts/tunnel-payload.py'))['prepare_bootstrap'](staging / 'Payload/zLoader.app', root)
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
ipa = out / ('zLoader-internal-unsigned.ipa' if args.internal else 'zLoader-unsigned.ipa')
# ditto preserves bundle links/permissions, unlike a naive Python ZIP writer.
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent',
                str(staging / 'Payload'), str(ipa)], check=True)
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
    assert any('/zLoaderTunnel.appex/' in name for name in archive.namelist()) == args.internal
    if not args.internal:
        assert 'Payload/zLoader.app/zLoaderTunnelPayload.zip' in archive.namelist()
result = {'artifact': ipa.name, 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
          'bundleIdentifier': info['CFBundleIdentifier'],
          'signing': 'unsigned; Apple provisioning required', 'internalProviderInstalled': args.internal,
          'bootstrapPayloadIncluded': not args.internal}
ipa.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
shutil.rmtree(staging)
print(json.dumps(result, indent=2))
