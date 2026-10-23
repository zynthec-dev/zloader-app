#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/AppleLogin80046
swiftc -swift-version 5 -module-cache-path .build/AppleLogin80046/ModuleCache \
    zLoader/Features/Core/Anisette/AnisetteServersManager.swift \
    zLoader/Tests/AnisetteServerMigrationTests.swift -o .build/AppleLogin80046/migration-tests
.build/AppleLogin80046/migration-tests
