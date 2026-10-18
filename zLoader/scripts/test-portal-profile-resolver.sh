#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/PortalProfileResolver
swiftc -module-cache-path .build/PortalProfileResolver/ModuleCache \
    zLoader/Features/Core/Operations/PipelineOperations/PortalProfileResolver.swift \
    zLoader/Tests/PortalProfileResolverTests.swift -o .build/PortalProfileResolver/tests
.build/PortalProfileResolver/tests
