#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
sh zLoader/scripts/apply-dependency-patches.sh
mkdir -p .build/WatchSigning
swiftc -module-cache-path .build/WatchSigning/ModuleCache \
    Dependencies/SideSign/Sources/Models/BundleSigningLayout.swift \
    zLoader/Tests/WatchSigningTests.swift -o .build/WatchSigning/tests
if [ "$#" -gt 0 ]; then
    work=$(mktemp -d /tmp/zloader-watch-fixture.XXXXXX)
    trap 'rm -rf "$work"' EXIT
    ditto -x -k "$1" "$work"
    set -- "$work"/Payload/*.app
    .build/WatchSigning/tests "$1"
else
    .build/WatchSigning/tests
fi
