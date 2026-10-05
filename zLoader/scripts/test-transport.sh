#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache -parse-as-library \
  SideStore/Core/Transport/TransportLeaseCoordinator.swift \
  zLoader/Tests/TransportLeaseTests.swift -o .build/zloader-transport-tests
.build/zloader-transport-tests
