#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/PortalAppID
swiftc -module-cache-path .build/PortalAppID/ModuleCache \
    Dependencies/SideSign/Sources/Models/Entitlement.swift \
    Dependencies/SideSign/Sources/Models/Feature.swift \
    Dependencies/SideSign/Sources/Models/AppID.swift \
    zLoader/Tests/PortalAppIDDecodingTests.swift -o .build/PortalAppID/tests
.build/PortalAppID/tests
