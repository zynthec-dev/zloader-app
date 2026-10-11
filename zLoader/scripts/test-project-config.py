"""Check the cross-target signing contract without reading local credentials."""
import json
import re
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parents[2]
project = json.loads(subprocess.check_output([
    'plutil', '-convert', 'json', '-o', '-', str(ROOT / 'zLoader.xcodeproj/project.pbxproj')
]))['objects']
expected = {
    'zLoader': ('', 'zLoader/Host.entitlements'),
    'zLoaderWidget': ('.Widget', 'zLoader/Widget/zLoaderWidget.entitlements'),
    'zLoaderBackup': ('.Backup', 'zLoader/Backup/zLoaderBackup.entitlements'),
}
assert all(o.get('name') == 'Release' for o in project.values() if o.get('isa') == 'XCBuildConfiguration')
seen = set()
for target in project.values():
    if target.get('isa') != 'PBXNativeTarget' or target.get('name') not in expected:
        continue
    name = target['name']
    seen.add(name)
    suffix, entitlement_file = expected[name]
    configurations = project[target['buildConfigurationList']]['buildConfigurations']
    assert len(configurations) == 1, name
    for configuration_id in configurations:
        configuration = project[configuration_id]
        settings = configuration['buildSettings']
        assert settings['PRODUCT_BUNDLE_IDENTIFIER'] == '$(MAIN_BUNDLE_IDENTIFIER)' + suffix, name
        assert settings['DEVELOPMENT_TEAM'] == '$(inherited)', name
        assert settings['CODE_SIGN_STYLE'] == 'Automatic', name
        assert settings['CODE_SIGN_ENTITLEMENTS'] == entitlement_file, name
        assert settings['IPHONEOS_DEPLOYMENT_TARGET'] == '$(ZLOADER_MIN_IOS_VERSION)', name
        assert '-w' not in settings.get('OTHER_LDFLAGS', []), name
    entitlements = plistlib.loads((ROOT / entitlement_file).read_bytes())
    assert ('com.apple.developer.networking.networkextension' in entitlements) == False
    if name in ('zLoader', 'zLoaderWidget', 'zLoaderBackup'):
        assert entitlements['com.apple.security.application-groups'] == ['group.$(APP_GROUP_IDENTIFIER)']
assert seen == set(expected)
assert not any(o.get('name') == 'zLoaderTunnel' for o in project.values())
build = (ROOT / 'Build.xcconfig').read_text()
assert build.count('#include? "CodeSigning.xcconfig"') == 1
assert build.rfind('#include? "CodeSigning.xcconfig"') > build.rfind('#include "zLoader/Branding.xcconfig"')
assert 'zLoaderFree.entitlements' not in build
assert 'ZLOADER_MIN_IOS_VERSION = 26.5' in build
assert '[config=Debug]' not in build
assert re.search(r'^MAIN_BUNDLE_IDENTIFIER\s*=\s*\$\(BASE_BUNDLE_ID\)$', build, re.M)
for scheme in (ROOT / 'zLoader.xcodeproj/xcshareddata/xcschemes').glob('*.xcscheme'):
    assert 'buildConfiguration = \"Debug\"' not in scheme.read_text(), scheme.name
assert 'MAIN_BUNDLE_IDENTIFIER=com.zynthec.zLoader' in (ROOT / 'zLoader/scripts/build-unsigned.sh').read_text()
print('PASS all three external-only targets: stable parent/child IDs, automatic signing, team inheritance, required entitlements and canonical release isolation')
