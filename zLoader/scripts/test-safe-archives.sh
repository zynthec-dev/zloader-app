#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
sh zLoader/scripts/apply-dependency-patches.sh
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache \
    Dependencies/SideSign/Sources/Archiver/ArchivePathPolicy.swift \
    zLoader/Tests/ArchivePathPolicyTests.swift -o .build/test-safe-archives
.build/test-safe-archives
