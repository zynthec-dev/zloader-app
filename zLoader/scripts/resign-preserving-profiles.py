"""Re-sign a private Apple-signed IPA with its original keychain identity and profiles."""
import argparse
import hashlib
from pathlib import Path
import runpy
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
signing = runpy.run_path(str(ROOT / 'zLoader/scripts/package-apple-signed.py'))
checks = signing['checks']
require = signing['require']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    require(args.ipa.resolve() != args.output.resolve(), 'Keep the original IPA for comparison')
    checks['verify'](args.ipa)
    with tempfile.TemporaryDirectory(dir=ROOT / '.build') as folder:
        temporary = Path(folder)
        subprocess.run(['ditto', '-x', '-k', str(args.ipa.resolve()), str(temporary)], check=True)
        host = next((temporary / 'Payload').glob('*.app'))
        embedded = host / 'zLoaderBackup.ipa'
        backup_folder = temporary / 'backup'
        subprocess.run(['ditto', '-x', '-k', str(embedded), str(backup_folder)], check=True)
        backup = next((backup_folder / 'Payload').glob('*.app'))
        bundles = [host, *host.glob('PlugIns/*.appex'), backup]
        before = {p.name: (checks['entitlements'](p), (p / 'embedded.mobileprovision').read_bytes()) for p in bundles}
        prefix = str(temporary / 'original-certificate-')
        subprocess.run(['codesign', '-d', '--extract-certificates=' + prefix, str(host)], capture_output=True, check=True)
        leaf = Path(prefix + '0').read_bytes()
        identity = hashlib.sha1(leaf).hexdigest().upper()
        for bundle in bundles:
            checks['check_profile'](bundle, before[bundle.name][0])
            cert_prefix = str(temporary / (bundle.name + '-certificate-'))
            subprocess.run(['codesign', '-d', '--extract-certificates=' + cert_prefix, str(bundle)], capture_output=True, check=True)
            require(Path(cert_prefix + '0').read_bytes() == leaf, 'Bundles do not use the same original certificate')
        entitlements = {name: record[0] for name, record in before.items()}
        signing['sign_bundle'](backup, identity, entitlements, temporary)
        signing['pack'](backup_folder / 'Payload', embedded)
        signing['sign_bundle'](host, identity, entitlements, temporary)
        for bundle in bundles:
            require(checks['entitlements'](bundle) == before[bundle.name][0], 'Re-signing changed an entitlement')
            require((bundle / 'embedded.mobileprovision').read_bytes() == before[bundle.name][1], 'Re-signing replaced an Apple profile')
            checks['check_profile'](bundle, before[bundle.name][0])
        args.output.parent.mkdir(exist_ok=True, parents=True)
        signing['pack'](temporary / 'Payload', args.output.resolve())
        checks['verify'](args.output)
        print('PASS repeated signing: host, every extension and backup retain original profile bytes and all entitlement values')
        print('SHA-256', hashlib.sha256(args.output.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
