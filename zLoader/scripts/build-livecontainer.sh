#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
platform=${1:-iphoneos}
case "$platform" in
    iphoneos) destination='generic/platform=iOS'; folder=LiveContainerDevice ;;
    iphonesimulator) destination='generic/platform=iOS Simulator'; folder=LiveContainerSimulator ;;
    *) echo "Container runtime is supported on iOS only" >&2; exit 1 ;;
esac
sh zLoader/scripts/prepare-livecontainer.sh
host=${MAIN_BUNDLE_IDENTIFIER:-com.zynthec.zLoader}
group="group.${APP_GROUP_IDENTIFIER:-$host}"
build="$PWD/.build/$folder"
mkdir -p "$build"
fingerprint=$(python3 - "$platform" "$host" "$group" <<'PY'
from pathlib import Path
import hashlib,sys
h=hashlib.sha256(('\0'.join(sys.argv[1:])).encode())
root=Path('Vendor/LiveContainer')
for p in sorted(root.rglob('*')):
    if p.is_file() and 'OpenSSL' not in p.relative_to(root).parts and '.git' not in p.parts:
        h.update(str(p.relative_to(root)).encode()); h.update(p.read_bytes())
print(h.hexdigest())
PY
)
product="$build/Build/Products/Release-$platform/LiveContainer.app"
if [ -f "$build/fingerprint" ] && [ "$(cat "$build/fingerprint")" = "$fingerprint" ] && [ -d "$product" ]; then
    exit 0
fi
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
# Xcode exports the host's SwiftPM resource-bundle names to script phases.
# They must not become build settings of this independent runtime project.
if ! env -i PATH="$PATH" HOME="$HOME" USER="${USER:-}" LOGNAME="${LOGNAME:-}" \
    TMPDIR="${TMPDIR:-/tmp}" DEVELOPER_DIR="$DEVELOPER_DIR" \
    /usr/bin/xcodebuild -project Vendor/LiveContainer/LiveContainer.xcodeproj -scheme LiveContainer \
    -configuration Release -destination "$destination" -derivedDataPath "$build" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES IPHONEOS_DEPLOYMENT_TARGET=26.5 CODE_SIGNING_ALLOWED=NO \
    LIVECONTAINER_BUNDLE_IDENTIFIER="$host" APP_GROUP_SIDESTORE="$group" APP_GROUP_ALTSTORE="$group" \
    build > "$build/build.log" 2>&1; then
    tail -100 "$build/build.log"
    exit 1
fi
printf '%s' "$fingerprint" > "$build/fingerprint"
echo "PASS embedded LiveContainer runtime: $platform"
