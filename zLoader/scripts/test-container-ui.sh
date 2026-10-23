#!/bin/sh
# Use a dedicated Simulator; synthetic fixture bundles are replaced in its app data.
set -eu
cd "$(dirname "$0")/../.."
: "${ZLOADER_SIMULATOR_ID:?Set ZLOADER_SIMULATOR_ID to a dedicated booted iPhone Simulator}"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
sh zLoader/scripts/prepare-container-fixtures.sh
xcodebuild -project zLoader.xcodeproj -scheme zLoader-ContainerTests -configuration Release \
    -destination "platform=iOS Simulator,id=$ZLOADER_SIMULATOR_ID" \
    -derivedDataPath .build/Simulator -clonedSourcePackagesDirPath .build/SourcePackages \
    -disableAutomaticPackageResolution -skipPackageUpdates \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
    MAIN_BUNDLE_IDENTIFIER=com.zynthec.zLoader APP_GROUP_IDENTIFIER=com.zynthec.zLoader build-for-testing
xcrun simctl install "$ZLOADER_SIMULATOR_ID" .build/Simulator/Build/Products/Release-iphonesimulator/zLoader.app
xcrun simctl terminate "$ZLOADER_SIMULATOR_ID" com.zynthec.zLoader 2>/dev/null || true
xcrun simctl install "$ZLOADER_SIMULATOR_ID" .build/ContainerFixtures/NativeCollision/Payload/NativeCollision.app
python3 - "$ZLOADER_SIMULATOR_ID" <<'PY'
from pathlib import Path
import plistlib,shutil,subprocess,sys
root=Path(subprocess.check_output(['xcrun','simctl','get_app_container',sys.argv[1],'com.zynthec.zLoader','data'],text=True).strip())/'Documents'
root.mkdir(exist_ok=True)
for name in ('Alpha','Beta','Legacy'):
    shutil.copy2(Path('.build/ContainerFixtures')/(name+'.ipa'),root/(name+'.ipa'))
    bundle=root/'Applications'/('de.zloader.acceptance.'+name.lower()+'.app')
    if bundle.exists():
        info=plistlib.loads((bundle/'Info.plist').read_bytes())
        assert info['CFBundleIdentifier']=='de.zloader.acceptance.'+name.lower()
        shutil.rmtree(bundle)
PY
python3 zLoader/Tests/ContainerFixture/server.py &
zloader_fixture_pid=$!
trap 'kill "$zloader_fixture_pid" 2>/dev/null || true' EXIT INT TERM
python3 - <<'PY'
import time,urllib.request
for attempt in range(50):
    try:
        with urllib.request.urlopen('http://127.0.0.1:18769/login',timeout=1) as response:
            assert b'code=synthetic' in response.read()
        break
    except OSError:
        if attempt==49: raise
        time.sleep(.1)
PY
kill -0 "$zloader_fixture_pid"
xcodebuild -project zLoader.xcodeproj -scheme zLoader-ContainerTests -configuration Release \
    -destination "platform=iOS Simulator,id=$ZLOADER_SIMULATOR_ID" \
    -derivedDataPath .build/Simulator -clonedSourcePackagesDirPath .build/SourcePackages \
    -disableAutomaticPackageResolution -skipPackageUpdates \
    -collect-test-diagnostics never \
    -resultBundlePath ".build/ContainerAcceptance-$(date -u +%Y%m%dT%H%M%SZ).xcresult" \
    test-without-building
xcrun simctl pbpaste "$ZLOADER_SIMULATOR_ID" | python3 -c '
import sys,urllib.parse
url=urllib.parse.urlsplit(sys.stdin.read()); query=urllib.parse.parse_qs(url.query)
assert url.scheme=="zloader" and url.netloc=="livecontainer-launch"
assert query.get("bundle-name")==["de.zloader.acceptance.alpha.app"] and query.get("container-folder-name")
print("PASS Home Screen shortcut targets the selected synthetic app and data container")'
