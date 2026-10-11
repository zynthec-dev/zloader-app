#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache -parse-as-library \
  zLoader/Features/Core/Transport/WireGuardConfiguration.swift \
  zLoader/Tests/WireGuardConfigurationTests.swift -o .build/zloader-wireguard-tests
.build/zloader-wireguard-tests
