#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache zLoader/Shared/AppValidity.swift zLoader/Tests/AppValidityTests.swift -o .build/test-app-validity
.build/test-app-validity
