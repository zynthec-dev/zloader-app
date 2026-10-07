#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache -parse-as-library \
  zLoader/Features/Core/Transport/TunnelPayloadManifest.swift \
  zLoader/Tests/TunnelPayloadTests.swift -o .build/zloader-tunnel-payload-tests
.build/zloader-tunnel-payload-tests
