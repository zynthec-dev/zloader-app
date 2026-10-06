"""Create complete ad-hoc re-signing metadata while preserving original Apple profiles.

This is not an Apple-authorized signature. The receiving signer must retain the
profiles or obtain equally capable matching profiles for its own certificate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import runpy
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
signing = runpy.run_path(str(ROOT / 'zLoader/scripts/package-apple-signed.py'))
checks = signing['checks']
require = signing['require']


def xml_entitlements(bundle):
    raw = (bundle / signing['info'](bundle)['CFBundleExecutable']).read_bytes()
    require(struct.unpack_from('<I', raw)[0] == 0xFEEDFACF, 'Expected thin arm64 Mach-O')
    offset = 32
    for _ in range(struct.unpack_from('<I', raw, 16)[0]):
        command, size = struct.unpack_from('<II', raw, offset)
        if command == 0x1D:
            start, length = struct.unpack_from('<II', raw, offset + 8)
            blob = raw[start:start + length]
            magic, _, count = struct.unpack_from('>III', blob)
            require(magic == 0xFADE0CC0, 'Invalid signature superblob')
            for index in range(count):
                slot, location = struct.unpack_from('>II', blob, 12 + index * 8)
                if slot == 5:
                    magic, length = struct.unpack_from('>II', blob, location)
                    require(magic == 0xFADE7171, 'Invalid entitlement blob')
                    return plistlib.loads(blob[location + 8:location + length])
        offset += size
    raise ValueError('Missing XML entitlement slot required by SideSign')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('signed_ipa', type=Path)
    args = parser.parse_args()
    checks['verify'](args.signed_ipa)
    with tempfile.TemporaryDirectory(dir=ROOT / '.build') as folder:
        temporary = Path(folder)
        subprocess.run(['ditto', '-x', '-k', str(args.signed_ipa.resolve()), str(temporary)], check=True)
        host = next((temporary / 'Payload').glob('*.app'))
        backup_ipa = host / 'zLoaderBackup.ipa'
        backup_folder = temporary / 'backup'
        subprocess.run(['ditto', '-x', '-k', str(backup_ipa), str(backup_folder)], check=True)
        backup = next((backup_folder / 'Payload').glob('*.app'))
        bundles = [host, *host.glob('PlugIns/*.appex'), backup]
        before = {p.name: (checks['entitlements'](p), (p / 'embedded.mobileprovision').read_bytes()) for p in bundles}
        for bundle in bundles:
            checks['check_profile'](bundle, before[bundle.name][0])
        entitlements = {name: record[0] for name, record in before.items()}
        signing['sign_bundle'](backup, '-', entitlements, temporary, require_apple=False)
        signing['pack'](backup_folder / 'Payload', backup_ipa)
        signing['sign_bundle'](host, '-', entitlements, temporary, require_apple=False)
        for bundle in bundles:
            require(checks['entitlements'](bundle) == before[bundle.name][0], 'Entitlement values changed')
            require(xml_entitlements(bundle) == before[bundle.name][0], 'SideSign XML import would lose entitlements')
            require((bundle / 'embedded.mobileprovision').read_bytes() == before[bundle.name][1], 'Apple profile bytes changed')
        version = signing['info'](host)['CFBundleShortVersionString']
        destination = ROOT / 'outputs' / f'zLoader-{version}-profile-resignable.ipa'
        signing['pack'](temporary / 'Payload', destination)
        manifest = {'artifact': destination.name, 'version': version,
                    'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
                    'bundles': [p.name for p in bundles], 'originalProfileBytesPreserved': True,
                    'allEntitlementsPreserved': True, 'xmlEntitlementSlotsChecked': True,
                    'signing': 'Ad-hoc import metadata; Apple re-signing required before installation',
                    'required': 'Matching private key and valid device-authorized profiles; other signers may replace metadata'}
        destination.with_suffix('.json').write_text(json.dumps(manifest, indent=2) + '\n')
        for alias in ['zLoader-profile-resignable']:
            shutil.copy2(destination, destination.with_name(alias + '.ipa'))
            destination.with_name(alias + '.json').write_text(json.dumps({**manifest, 'artifact': alias + '.ipa'}, indent=2) + '\n')
        print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
