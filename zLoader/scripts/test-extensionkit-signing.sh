#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
sh zLoader/scripts/apply-dependency-patches.sh
mkdir -p .build/ExtensionKitSigning
swiftc -module-cache-path .build/ExtensionKitSigning/ModuleCache \
    Dependencies/SideSign/Sources/Models/BundleSigningLayout.swift \
    zLoader/Tests/ExtensionKitSigningTests.swift -o .build/ExtensionKitSigning/tests
if [ "$#" -gt 0 ]; then
    work=$(mktemp -d /tmp/zloader-extensionkit-fixture.XXXXXX)
    trap 'rm -rf "$work"' EXIT
    ditto -x -k "$1" "$work"
    set -- "$work"/Payload/*.app
    .build/ExtensionKitSigning/tests "$1"
else
    .build/ExtensionKitSigning/tests
fi
