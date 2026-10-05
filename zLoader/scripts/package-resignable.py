"""Preserve capability requests for iLoader / SideStore re-signing.

Ad-hoc signatures describe required entitlements; they do not grant iOS App
Groups or Network Extension access. A real signer must provision and sign both
host and extensions with Apple's matching profiles before installation.
"""
import hashlib
import argparse
import sys
import json
import plistlib
import shutil
import subprocess
from pathlib import Path
import zipfile
import struct

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--signed-ipa', type=Path, help='Keep all entitlements and profiles from a private Apple-signed IPA')
args = parser.parse_args()
if args.signed_ipa:
    subprocess.run([sys.executable, str(root / 'zLoader/scripts/package-profile-resignable.py'),
                    str(args.signed_ipa.resolve())], check=True)
    raise SystemExit(0)

source = root / '.build/Device/Build/Products/Release-iphoneos/zLoader.app'
out = root / 'outputs'
out.mkdir(exist_ok=True)
staging = out / 'resignable-staging'
if staging.exists():
    shutil.rmtree(staging)
app = staging / 'Payload/zLoader.app'
shutil.copytree(source, app, symlinks=True)
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.zynthec.zLoader'
group = 'group.' + info['CFBundleIdentifier']
app_groups_key = 'com.apple.security.application-groups'
ne_key = 'com.apple.developer.networking.networkextension'
def requested_entitlements(relative_path):
    raw = (root / relative_path).read_text().replace('$(APP_GROUP_IDENTIFIER)', info['CFBundleIdentifier'])
    result = plistlib.loads(raw.encode('utf-8'))
    assert '$(' not in str(result), 'Unexpanded entitlement build setting'
    return result

expected = {
    app: requested_entitlements('zLoader/Host.entitlements'),
    app / 'PlugIns/zLoaderWidget.appex': requested_entitlements('zLoader/Widget/zLoaderWidget.entitlements'),
    app / 'PlugIns/zLoaderTunnel.appex': requested_entitlements('zLoader/Tunnel/zLoaderTunnel.entitlements'),
}
assert expected[app][app_groups_key] == [group]
assert expected[app / 'PlugIns/zLoaderWidget.appex'][app_groups_key] == [group]
for bundle in [app, app / 'PlugIns/zLoaderTunnel.appex']:
    assert expected[bundle][ne_key] == ['packet-tunnel-provider']

def sign(path, entitlements=None):
    args = ['codesign', '--force', '--sign', '-', '--timestamp=none']
    if entitlements is not None:
        metadata = staging / (path.name + '.entitlements')
        metadata.write_bytes(plistlib.dumps(entitlements))
        args += ['--entitlements', str(metadata)]
    args.append(str(path))
    subprocess.run(args, check=True, capture_output=True)

# Seal nested executable bundles before their parents; do not apply host
# entitlements to arbitrary nested code with --deep.
for framework in sorted(app.rglob('*.framework'), key=lambda p: len(p.parts), reverse=True):
    sign(framework)
for dylib in app.rglob('*.dylib'):
    sign(dylib)
for path in list(expected)[1:]:
    sign(path, expected[path])
sign(app, expected[app])
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True, capture_output=True)
def xml_entitlements(path):
    # SideSign's MachOParser reads CSSLOT_ENTITLEMENTS (5). Check that exact
    # slot, not just codesign's decoded representation of DER entitlements.
    bundle_info = plistlib.loads((path / 'Info.plist').read_bytes())
    raw = (path / bundle_info['CFBundleExecutable']).read_bytes()
    assert struct.unpack_from('<I', raw)[0] == 0xFEEDFACF
    ncmds = struct.unpack_from('<I', raw, 16)[0]
    offset = 32
    for _ in range(ncmds):
        cmd, length = struct.unpack_from('<II', raw, offset)
        if cmd == 0x1D:
            signature, size = struct.unpack_from('<II', raw, offset + 8)
            blob = raw[signature:signature + size]
            magic, total, count = struct.unpack_from('>III', blob)
            assert magic == 0xFADE0CC0
            for index in range(count):
                slot, location = struct.unpack_from('>II', blob, 12 + index * 8)
                if slot == 5:
                    magic, length = struct.unpack_from('>II', blob, location)
                    assert magic == 0xFADE7171
                    return plistlib.loads(blob[location + 8:location + length])
        offset += length
    raise AssertionError('Missing XML entitlement slot required by SideSign import')

for path, requirements in expected.items():
    result = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', str(path)], check=True, capture_output=True)
    actual = plistlib.loads(result.stdout)
    imported = xml_entitlements(path)
    for key, value in requirements.items():
        assert actual[key] == value, (path.name, key)
        assert imported[key] == value, (path.name, key, "SideSign XML import")

ipa = out / 'zLoader-resignable.ipa'
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(staging / 'Payload'), str(ipa)], check=True)
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
manifest = {
    'artifact': ipa.name,
    'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
    'appGroup': group,
    'capabilitiesByBundle': {str(path.relative_to(staging / 'Payload')): requirements for path, requirements in expected.items()},
    'signing': 'ad-hoc capability metadata only; not authorized or directly installable on iOS',
    'required': 'Real Apple provisioning and signing for App Groups (host/widget) and Network Extension (host/tunnel)',
}
(out / 'zLoader-resignable.json').write_text(json.dumps(manifest, indent=2) + '\n')
# No Apple signing identity is used. iLoader replaces these local metadata
# signatures with signatures and entitlements from its downloaded profiles.
iloader_ipa = out / 'zLoader-iLoader.ipa'
shutil.copy2(ipa, iloader_ipa)
iloader_manifest = {**manifest, 'artifact': iloader_ipa.name}
(out / 'zLoader-iLoader.json').write_text(json.dumps(iloader_manifest, indent=2) + '\n')
shutil.rmtree(staging)
print(json.dumps(iloader_manifest, indent=2))
