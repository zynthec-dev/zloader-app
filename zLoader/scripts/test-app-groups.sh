#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache -parse-as-library \
  zLoader/Shared/Extensions/AppGroupResolver.swift zLoader/Tests/AppGroupResolverTests.swift \
  -o .build/zloader-app-group-tests
.build/zloader-app-group-tests
