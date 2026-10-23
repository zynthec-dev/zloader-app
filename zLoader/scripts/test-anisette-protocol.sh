#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
work=.build/AppleLogin80046/protocol
mkdir -p "$work"
swiftc -swift-version 6 -module-cache-path "$work/ModuleCache" -module-name AnisetteKit \
    -emit-library -emit-module zLoader/Tests/RemoteAnisetteProtocolSupport.swift \
    -emit-module-path "$work/AnisetteKit.swiftmodule" -o "$work/libAnisetteKit.dylib"
swiftc -swift-version 6 -module-cache-path "$work/ModuleCache" -I "$work" -L "$work" -lAnisetteKit \
    Dependencies/SideSign/Sources/DeveloperPortal/AppleLoginCompatibility.swift \
    Dependencies/SideSign/Sources/Anisette/RemoteAnisetteDataProvider.swift \
    zLoader/Tests/RemoteAnisetteProtocolTests.swift -o "$work/tests"
DYLD_LIBRARY_PATH="$PWD/$work" "$work/tests"
