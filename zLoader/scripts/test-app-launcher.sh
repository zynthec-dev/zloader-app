#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/AppLauncher
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer} xcrun --sdk macosx clang \
    -fobjc-arc -fblocks -Wall -Wextra -DZLOADER_APP_LAUNCH_TESTING=1 \
    -framework Foundation zLoader/App/Core/UI/ZLoaderAppLauncher.m zLoader/Tests/AppLauncherTests.m \
    -o .build/AppLauncher/tests
for mode in modern-success modern-failure legacy unavailable invalid; do
    .build/AppLauncher/tests "$mode"
done
