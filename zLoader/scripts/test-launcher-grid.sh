#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/LauncherGridModuleCache
launcher_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
SDKROOT="$launcher_sdk" xcrun swiftc -swift-version 5 -sdk "$launcher_sdk" \
  -target arm64-apple-ios26.5-simulator -module-cache-path .build/LauncherGridModuleCache \
  zLoader/App/Core/DataSources/*.swift zLoader/App/Extensions/NSPredicate+Search.swift \
  zLoader/Tests/LauncherGridTests.swift -o .build/test-launcher-grid
xcrun simctl spawn booted "$PWD/.build/test-launcher-grid"
