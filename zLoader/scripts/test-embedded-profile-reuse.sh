#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache \
  zLoader/Features/Core/Operations/PipelineOperations/PacketTunnelProvisioning.swift \
  zLoader/Features/Core/Operations/PipelineOperations/EmbeddedProfileReuse.swift \
  zLoader/Tests/EmbeddedProfileReuseTests.swift -o .build/test-embedded-profile-reuse
.build/test-embedded-profile-reuse
