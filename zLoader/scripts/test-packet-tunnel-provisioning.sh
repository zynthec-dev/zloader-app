#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache \
  zLoader/Features/Core/Operations/PipelineOperations/PacketTunnelProvisioning.swift \
  zLoader/Tests/PacketTunnelProvisioningTests.swift -o .build/test-packet-tunnel-provisioning
.build/test-packet-tunnel-provisioning
