"""Verify real external/full IPA layout and dormant-provider identity/version integrity."""
import hashlib
import io
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[2]
for internal in [False]:
    ipa = root / 'outputs' / 'zLoader-resignable.ipa'
    with zipfile.ZipFile(ipa) as archive:
        assert archive.testzip() is None
        assert any('/PlugIns/zLoaderTunnel.appex/' in name for name in archive.namelist()) == internal
        info = plistlib.loads(archive.read('Payload/zLoader.app/Info.plist'))
        assert 'Payload/zLoader.app/PlugIns/zLoaderWidget.appex/Info.plist' in archive.namelist()
        for name in ['LiveProcess', 'LaunchAppExtension', 'ShareExtension']:
            child = plistlib.loads(archive.read('Payload/zLoader.app/PlugIns/' + name + '.appex/Info.plist'))
            assert child['CFBundleIdentifier'] == info['CFBundleIdentifier'] + '.' + name
            assert child['CFBundleShortVersionString'] == info['CFBundleShortVersionString']
            assert child['CFBundleVersion'] == info['CFBundleVersion']
        for name in ['LiveContainerShared.framework/LiveContainerShared', 'LiveContainerSwiftUI.framework/LiveContainerSwiftUI', 'TweakLoader.dylib', 'ZSign.dylib']:
            assert 'Payload/zLoader.app/Frameworks/' + name in archive.namelist()
        assert 'Payload/zLoader.app/LiveContainerResources.bundle/de.lproj/Localizable.strings' in archive.namelist()
        assert 'Payload/zLoader.app/LiveContainer-License.md' in archive.namelist()
        assert not any('zLoaderTunnelPayload' in name for name in archive.namelist())
        assert not any(name.endswith('embedded.mobileprovision') for name in archive.namelist())
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(['ditto', '-x', '-k', str(ipa), folder], check=True)
        host = Path(folder) / 'Payload/zLoader.app'
        declared = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', '-', '--xml', str(host)], stderr=subprocess.DEVNULL))
        assert ('com.apple.developer.networking.networkextension' in declared) == internal
        assert declared['com.apple.security.application-groups'] == ['group.com.zynthec.zLoader']
        assert len(declared['keychain-access-groups']) == 128
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(host)], check=True, capture_output=True)
print('PASS external-only IPA: no tunnel provider, recovery payload or host Network Extension entitlement; widget and App Group signatures intact')
