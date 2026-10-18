#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/AppleLoginTests
swiftc -swift-version 6 -module-cache-path .build/AppleLoginTests/ModuleCache \
    Dependencies/SideSign/Sources/DeveloperPortal/AppleLoginCompatibility.swift \
    zLoader/Tests/AppleLoginCompatibilityTests.swift -o .build/AppleLoginTests/tests
.build/AppleLoginTests/tests
