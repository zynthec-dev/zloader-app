"""Build an Apple-signed repair IPA using the installed app's exact identities.

Requires an eligible team configured in Xcode and a local signing private key.
Apple may create/update development profiles. No credentials are exported.
"""
import argparse
import hashlib
from pathlib import Path
import plistlib
import re
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
checks = runpy.run_path(str(ROOT / 'zLoader/scripts/verify-signed-ipa.py'))
pack = runpy.run_path(str(ROOT / 'zLoader/scripts/package-apple-signed.py'))['pack']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle-id', required=True)
    parser.add_argument('--app-group', required=True)
    args = parser.parse_args()
    # Values are identifiers, never shell commands or credentials.
    for value in (args.bundle_id, args.app_group):
        checks['require'](re.fullmatch(r'[A-Za-z0-9.-]+', value), 'Invalid identifier')
    checks['require'](args.app_group.startswith('group.'), 'Expected full App Group ID')
    subprocess.run(['sh', 'zLoader/scripts/apply-dependency-patches.sh'], cwd=ROOT, check=True)
    with tempfile.TemporaryDirectory(prefix='.zloader-recovery-', suffix='.xcodeproj', dir=ROOT) as folder:
        project = Path(folder)
        shutil.copytree(ROOT / 'zLoader.xcodeproj', project, dirs_exist_ok=True)
        pbx = project / 'project.pbxproj'
        text = pbx.read_text()
        # Only the scratch project's target settings change. User edits remain intact.
        def resolve_target(match):
            settings = match.group(0)
            paths = {'App': '', 'Backup': '.Backup', 'Widget': '.Widget', 'Tunnel': '.Tunnel'}
            suffix = next((suffix for directory, suffix in paths.items()
                           if 'INFOPLIST_FILE = zLoader/' + directory + '/Info.plist;' in settings), None)
            if suffix is None:
                return settings
            if suffix == '.Widget':
                settings = re.sub(r'(CURRENT_PROJECT_VERSION|MARKETING_VERSION) = [^;]+;',
                                  r'\1 = "$(inherited)";', settings)
            value = 'PRODUCT_BUNDLE_IDENTIFIER = "$(MAIN_BUNDLE_IDENTIFIER)' + suffix + '";'
            if 'PRODUCT_BUNDLE_IDENTIFIER =' in settings:
                return re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;', value, settings)
            return settings.replace('buildSettings = {', 'buildSettings = {\n\t\t\t\t' + value, 1)
        text = re.sub(r'buildSettings = \{.*?\n\t\t\t\};', resolve_target, text, flags=re.S)
        pbx.write_text(text)
        for scheme in project.rglob('*.xcscheme'):
            scheme.write_text(scheme.read_text().replace('container:zLoader.xcodeproj', 'container:' + project.name))
        log = ROOT / '.build/apple-recovery-build.log'
        log.parent.mkdir(exist_ok=True)
        with log.open('w') as output:
            result = subprocess.run([
                'xcodebuild', '-project', str(project), '-scheme', 'zLoader', '-configuration', 'Debug',
                '-destination', 'generic/platform=iOS', '-derivedDataPath', '.build/Recovery',
                '-clonedSourcePackagesDirPath', '.build/SourcePackages', '-allowProvisioningUpdates',
                'MAIN_BUNDLE_IDENTIFIER=' + args.bundle_id,
                'APP_GROUP_IDENTIFIER=' + args.app_group.removeprefix('group.'), 'build',
            ], cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        checks['require'](result.returncode == 0, 'Apple build failed; inspect .build/apple-recovery-build.log')
    products = ROOT / '.build/Recovery/Build/Products/Debug-iphoneos'
    with tempfile.TemporaryDirectory(dir=ROOT / '.build') as folder:
        temporary = Path(folder)
        app = temporary / 'Payload/zLoader.app'
        backup = temporary / 'backup/Payload/zLoaderBackup.app'
        shutil.copytree(products / 'zLoader.app', app, symlinks=True)
        shutil.copytree(products / 'zLoaderBackup.app', backup, symlinks=True)
        suffixes = {'zLoader.app': '', 'zLoaderBackup.app': '.Backup',
                    'zLoaderWidget.appex': '.Widget', 'zLoaderTunnel.appex': '.Tunnel'}
        for component in [app, *app.glob('PlugIns/*.appex'), backup]:
            info = plistlib.loads((component / 'Info.plist').read_bytes())
            checks['require'](info['CFBundleIdentifier'] == args.bundle_id + suffixes[component.name],
                              'Repair bundle identity differs from the requested installation')
            entitlements = checks['entitlements'](component)
            checks['check_profile'](component, entitlements)
            if component.name in ('zLoader.app', 'zLoaderWidget.appex'):
                checks['require'](args.app_group in entitlements.get(checks['GROUPS'], []),
                                  'Repair would change the installed shared App Group')
        subprocess.run(['codesign', '--verify', '--deep', '--strict', '-R=anchor apple generic',
                        str(backup)], check=True)
        embedded = app / 'zLoaderBackup.ipa'
        if embedded.exists() or embedded.is_symlink():
            embedded.unlink()
        pack(backup.parent, embedded)
        prefix = str(temporary / 'certificate-')
        subprocess.run(['codesign', '-d', '--extract-certificates=' + prefix, str(app)], capture_output=True, check=True)
        identity = hashlib.sha1(Path(prefix + '0').read_bytes()).hexdigest().upper()
        entitlements_file = temporary / 'host.plist'
        entitlements_file.write_bytes(plistlib.dumps(checks['entitlements'](app)))
        subprocess.run(['codesign', '--force', '--sign', identity, '--timestamp=none',
                        '--generate-entitlement-der', '--entitlements', str(entitlements_file), str(app)], check=True)
        version = plistlib.loads((app / 'Info.plist').read_bytes())['CFBundleShortVersionString']
        output = ROOT / 'outputs' / f'zLoader-{version}-Apple-recovery.ipa'
        output.parent.mkdir(exist_ok=True)
        pack(app.parent, output)
        checks['verify'](output)
        print('Verified repair IPA:', output)
        print('SHA-256:', hashlib.sha256(output.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
