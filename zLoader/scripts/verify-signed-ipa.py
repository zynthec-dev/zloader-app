"""Check iLoader's resulting signed IPA, without changing it or reading credentials.

Requires macOS codesign/security. Does not contact Apple or establish device launch.
"""
import argparse
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
    for key in [GROUPS, NETWORK]:
        for value in requested.get(key, []):
            require(any(fnmatch.fnmatchcase(value, allowed) for allowed in authorized.get(key, [])),
                    f'{bundle.name}: profile does not authorize {key}')
    return team


def verify(ipa):
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        subprocess.run(['ditto', '-x', '-k', str(ipa.resolve()), str(root)], check=True)
        hosts = list((root / 'Payload').glob('*.app'))
        require(len(hosts) == 1, 'Expected exactly one host app')
        host = hosts[0]
        widget = host / 'PlugIns/zLoaderWidget.appex'
        tunnel = host / 'PlugIns/zLoaderTunnel.appex'
        require(widget.is_dir() and tunnel.is_dir(), 'Widget or tunnel was removed during signing')
        subprocess.run(['codesign', '--verify', '--deep', '--strict', '-R=anchor apple generic', str(host)], check=True)
        declared = {bundle: entitlements(bundle) for bundle in [host, widget, tunnel]}
        require(bool(set(declared[host].get(GROUPS, [])) & set(declared[widget].get(GROUPS, []))),
                'Host and widget need the same signed App Group')
        for bundle in [host, tunnel]:
            require('packet-tunnel-provider' in declared[bundle].get(NETWORK, []),
                    f'{bundle.name}: packet-tunnel-provider was omitted by the signer')
        teams = {check_profile(bundle, requested) for bundle, requested in declared.items()}
        require(len(teams) == 1, 'Host and extensions are signed by different teams')
        print('PASS signed bundle integrity, shared App Group, tunnel entitlements and matching profiles')
        print('Profile expiry, device authorization and physical launch still require device validation.')


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
