#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/PortalCapabilities
swiftc -D PORTAL_CAPABILITY_TESTS -module-cache-path .build/PortalCapabilities/ModuleCache \
    Dependencies/SideSign/Sources/DeveloperPortal/PortalCapabilities.swift \
    zLoader/Tests/PortalCapabilityGraphTests.swift -o .build/PortalCapabilities/tests
.build/PortalCapabilities/tests
