"""Check a resulting Apple-signed IPA, without changing it or reading credentials.

Requires macOS codesign/security. Does not contact Apple or establish device launch.
"""
import argparse
from datetime import datetime, timezone
import fnmatch
import plistlib
from pathlib import Path
import subprocess
import tempfile
import zipfile

GROUPS = 'com.apple.security.application-groups'
NETWORK = 'com.apple.developer.networking.networkextension'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def entitlements(bundle):
    result = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', str(bundle)],
                            capture_output=True, check=True)
    return plistlib.loads(result.stdout)


def check_profile(bundle, requested):
    path = bundle / 'embedded.mobileprovision'
    require(path.is_file(), f'{bundle.name}: missing Apple provisioning profile')
    result = subprocess.run(['security', 'cms', '-D', '-i', str(path)], capture_output=True, check=True)
    profile = plistlib.loads(result.stdout)
    expiry = profile['ExpirationDate'].replace(tzinfo=timezone.utc)
    require(expiry > datetime.now(timezone.utc), f'{bundle.name}: expired provisioning profile')
    with tempfile.TemporaryDirectory() as certificates:
        prefix = str(Path(certificates) / 'certificate-')
        subprocess.run(['codesign', '-d', '--extract-certificates=' + prefix, str(bundle)],
                       capture_output=True, check=True)
        leaf = Path(prefix + '0').read_bytes()
        require(leaf in profile.get('DeveloperCertificates', []),
                f'{bundle.name}: signing certificate is not authorized by profile')
    authorized = profile['Entitlements']
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    actual_id = requested.get('application-identifier', '')
    team = requested.get('com.apple.developer.team-identifier', '')
    require(bool(team) and actual_id.endswith('.' + info['CFBundleIdentifier']),
            f'{bundle.name}: missing/mismatched signed application identity')
    require(fnmatch.fnmatchcase(actual_id, authorized.get('application-identifier', '')),
            f'{bundle.name}: profile does not authorize signed application identity')
    require(team in profile.get('TeamIdentifier', []), f'{bundle.name}: profile team mismatch')
    require(authorized.get('com.apple.developer.team-identifier') == team,
            f'{bundle.name}: entitlement team mismatch')
    for key, value in requested.items():
        allowed = authorized.get(key)
        if isinstance(value, str):
            permitted = isinstance(allowed, str) and fnmatch.fnmatchcase(value, allowed)
        elif isinstance(value, list):
            permitted = isinstance(allowed, list) and all(
                any(isinstance(item, str) and isinstance(rule, str) and fnmatch.fnmatchcase(item, rule)
                    or item == rule for rule in allowed) for item in value
            )
        elif isinstance(value, bool):
            permitted = not value or allowed is True
        else:
            permitted = value == allowed
        require(permitted, f'{bundle.name}: profile does not authorize {key}')
    return team


def verify(ipa):
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        subprocess.run(['ditto', '-x', '-k', str(ipa.resolve()), str(root)], check=True)
        hosts = list((root / 'Payload').glob('*.app'))
        require(len(hosts) == 1, 'Expected exactly one host app')
        host = hosts[0]
        widget = host / 'PlugIns/zLoaderWidget.appex'
        require(widget.is_dir(), 'Widget was removed during signing')
        tunnel = host / 'PlugIns/zLoaderTunnel.appex'
        subprocess.run(['codesign', '--verify', '--deep', '--strict', '-R=anchor apple generic', str(host)], check=True)
        declared = {bundle: entitlements(bundle) for bundle in [host, *host.glob('PlugIns/*.appex')]}
        require(bool(set(declared[host].get(GROUPS, [])) & set(declared[widget].get(GROUPS, []))),
                'Host and widget need the same signed App Group')
        require((NETWORK in declared[host]) == tunnel.exists(), 'Provider and host Network Extension requirements differ')
        if tunnel.exists():
            require('packet-tunnel-provider' in declared[tunnel].get(NETWORK, []), 'Provider lacks required entitlement')
        teams = {check_profile(bundle, requested) for bundle, requested in declared.items()}
        backup_ipa = host / 'zLoaderBackup.ipa'
        require(backup_ipa.is_file(), 'Embedded Backup IPA was removed')
        with zipfile.ZipFile(backup_ipa) as archive:
            require(archive.testzip() is None, 'Invalid embedded Backup ZIP')
        backup_root = root / 'Backup'
        subprocess.run(['ditto', '-x', '-k', str(backup_ipa), str(backup_root)], check=True)
        backups = list((backup_root / 'Payload').glob('*.app'))
        require(len(backups) == 1, 'Expected one embedded Backup app')
        backup = backups[0]
        subprocess.run(['codesign', '--verify', '--deep', '--strict', '-R=anchor apple generic', str(backup)], check=True)
        backup_entitlements = entitlements(backup)
        teams.add(check_profile(backup, backup_entitlements))
        require(set(declared[host].get(GROUPS, [])) == set(backup_entitlements.get(GROUPS, [])),
                'Host and Backup must retain the same signed App Group')
        host_id = plistlib.loads((host / 'Info.plist').read_bytes())['CFBundleIdentifier']
        for child, suffix in [(widget, '.Widget'), (backup, '.Backup')] + ([(tunnel, '.Tunnel')] if tunnel.exists() else []):
            child_id = plistlib.loads((child / 'Info.plist').read_bytes())['CFBundleIdentifier']
            require(child_id == host_id + suffix, f'{child.name}: identity is not derived from host')
        require(len(teams) == 1, 'Host, extensions and Backup are signed by different teams')
        print('PASS Apple-signed integrity, all extensions and embedded Backup, authorized certificates, current profiles, shared App Group and consistent provider authorization')
        print('Registered-device eligibility and physical launch still require device validation.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    args = parser.parse_args()
    try:
        with zipfile.ZipFile(args.ipa) as archive:
            require(archive.testzip() is None, 'Invalid ZIP content')
        verify(args.ipa)
    except (ValueError, KeyError, plistlib.InvalidFileException, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        raise SystemExit(f'FAIL: {error}')
