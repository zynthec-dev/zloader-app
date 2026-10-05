"""Build and sign privately using a valid local Xcode installation's identities/profiles.

Uses the existing keychain identity; never exports its private key. Includes every
extension and a separately signed embedded backup IPA. Outputs are git-ignored.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import runpy
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
checks = runpy.run_path(str(ROOT / 'zLoader/scripts/verify-signed-ipa.py'))
require = checks['require']
read_entitlements = checks['entitlements']


def info(bundle):
    return plistlib.loads((bundle / 'Info.plist').read_bytes())


def profile(bundle):
    result = subprocess.run(['security', 'cms', '-D', '-i', str(bundle / 'embedded.mobileprovision')],
                            capture_output=True, check=True)
    return plistlib.loads(result.stdout)


def pack(payload, destination):
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(payload), str(destination)], check=True)
    with zipfile.ZipFile(destination) as archive:
        require(archive.testzip() is None, 'Invalid packaged ZIP')


def sign_bundle(bundle, identity, entitlements, temporary):
    magic = {bytes.fromhex(x) for x in ['feedface', 'cefaedfe', 'feedfacf', 'cffaedfe', 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca']}
    # Sign dependencies first, then framework seals, extension seals and the host.
    for file in bundle.rglob('*'):
        if file.is_file() and not file.is_symlink():
            with file.open('rb') as stream:
                macho = stream.read(4) in magic
            if macho:
                subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none', str(file)],
                               capture_output=True, check=True)
    for framework in sorted(bundle.rglob('*.framework'), key=lambda p: len(p.parts), reverse=True):
        subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none', str(framework)],
                       capture_output=True, check=True)
    for component in [*sorted(bundle.glob('PlugIns/*.appex')), bundle]:
        path = temporary / (component.name + '.entitlements.plist')
        path.write_bytes(plistlib.dumps(entitlements[component.name]))
        subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none',
                        '--generate-entitlement-der', '--entitlements', str(path), str(component)],
                       capture_output=True, check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', '-R=anchor apple generic', str(bundle)],
                   capture_output=True, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-app', type=Path)
    args = parser.parse_args()
    candidates = [args.reference_app] if args.reference_app else list(
        (Path.home() / 'Library/Developer/Xcode/DerivedData').glob('zLoader-*/Build/Products/Debug-iphoneos/zLoader.app')
    )
    require(len(candidates) == 1, 'Provide one unambiguous --reference-app with valid Xcode profiles')
    reference = candidates[0]
    backup_reference = reference.parent / 'zLoaderBackup.app'
    references = [reference, *reference.glob('PlugIns/*.appex'), backup_reference]
    require({p.name for p in references} >= {'zLoader.app', 'zLoaderWidget.appex', 'zLoaderTunnel.appex', 'zLoaderBackup.app'},
            'Host, all extensions and backup profiles are required')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', '-R=anchor apple generic', str(reference)],
                   capture_output=True, check=True)
    declared = {p.name: read_entitlements(p) for p in references}
    teams = {checks['check_profile'](p, declared[p.name]) for p in references}
    require(len(teams) == 1, 'Profiles must belong to the same team')
    decoded = {p.name: profile(p) for p in references}
    devices = set.intersection(*[set(p.get('ProvisionedDevices', [])) for p in decoded.values()])
    require(bool(devices), 'Development profiles have no commonly authorized device')
    identities = subprocess.run(['security', 'find-identity', '-v', '-p', 'codesigning'],
                                capture_output=True, check=True)
    available = set(re.findall(r'\b[0-9A-F]{40}\b', identities.stdout.decode()))
    with tempfile.TemporaryDirectory(dir=ROOT / '.build') as folder:
        temporary = Path(folder)
        prefix = str(temporary / 'xcode-certificate-')
        subprocess.run(['codesign', '-d', '--extract-certificates=' + prefix, str(reference)], capture_output=True, check=True)
        certificate = Path(prefix + '0').read_bytes()
        identity = hashlib.sha1(certificate).hexdigest().upper()
        require(identity in available, 'The original Xcode signing private key is unavailable in the keychain')
        require(all(certificate in p.get('DeveloperCertificates', []) for p in decoded.values()),
                'Original certificate is not authorized by every profile')
        subprocess.run(['sh', 'zLoader/scripts/apply-dependency-patches.sh'], cwd=ROOT, check=True)
        log = ROOT / '.build/apple-signed-build.log'
        with log.open('w') as output:
            result = subprocess.run([
                'xcodebuild', '-project', 'zLoader.xcodeproj', '-scheme', 'zLoader', '-configuration', 'Release',
                '-destination', 'generic/platform=iOS', '-derivedDataPath', '.build/Device',
                '-clonedSourcePackagesDirPath', '.build/SourcePackages', 'CODE_SIGNING_ALLOWED=NO',
                'MAIN_BUNDLE_IDENTIFIER=' + info(reference)['CFBundleIdentifier'],
                'APP_GROUP_IDENTIFIER=' + info(reference)['CFBundleIdentifier'],
            ], cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        require(result.returncode == 0, 'Build failed; inspect .build/apple-signed-build.log')
        products = ROOT / '.build/Device/Build/Products/Release-iphoneos'
        payload = temporary / 'Payload'
        app = payload / 'zLoader.app'
        shutil.copytree(products / 'zLoader.app', app, symlinks=True)
        backup_payload = temporary / 'backup/Payload'
        backup = backup_payload / 'zLoaderBackup.app'
        shutil.copytree(products / 'zLoaderBackup.app', backup, symlinks=True)
        targets = [app, *app.glob('PlugIns/*.appex'), backup]
        require({p.name for p in targets} == {p.name for p in references}, 'An extension was added or removed; matching profiles required')
        for target in targets:
            source = next(p for p in references if p.name == target.name)
            require(info(target)['CFBundleIdentifier'] == info(source)['CFBundleIdentifier'], 'Bundle identity changed')
            shutil.copy2(source / 'embedded.mobileprovision', target / 'embedded.mobileprovision')
        sign_bundle(backup, identity, declared, temporary)
        checks['check_profile'](backup, read_entitlements(backup))
        backup_ipa = app / 'zLoaderBackup.ipa'
        if backup_ipa.is_symlink():
            backup_ipa.unlink()
        pack(backup_payload, backup_ipa)
        sign_bundle(app, identity, declared, temporary)
        for target in targets:
            require(read_entitlements(target) == declared[target.name], 'Signed entitlements changed')
            checks['check_profile'](target, declared[target.name])
        version = info(app)['CFBundleShortVersionString']
        destination = ROOT / 'outputs' / f'zLoader-{version}-Apple-signed.ipa'
        destination.parent.mkdir(exist_ok=True)
        pack(payload, destination)
        checks['verify'](destination)
        manifest = {'artifact': destination.name, 'version': version,
                    'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
                    'signing': 'Original local Apple Development identity, unchanged Xcode profiles and signed entitlements',
                    'bundles': [p.name for p in targets], 'profilesCurrent': True,
                    'commonRegisteredDevicesPresent': True, 'privateKeyExported': False,
                    'physicalInstallAndSelfRefresh': 'not tested'}
        destination.with_suffix('.json').write_text(json.dumps(manifest, indent=2) + '\n')
        print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
