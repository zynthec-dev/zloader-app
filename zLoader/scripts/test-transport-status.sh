#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache -parse-as-library \
 zLoader/Features/Core/Transport/TransportStatusPresentation.swift \
 zLoader/Tests/TransportStatusTests.swift -o .build/zloader-status-tests
.build/zloader-status-tests
