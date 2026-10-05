#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache Shared/Extensions/ManagedObjectContext+Confinement.swift zLoader/Tests/ContextConfinementTests.swift -o .build/test-context
.build/test-context
