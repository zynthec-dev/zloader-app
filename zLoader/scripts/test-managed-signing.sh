#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/ManagedSigning
swiftc -module-cache-path .build/ManagedSigning/ModuleCache Dependencies/SideSign/Sources/Models/CertificateType.swift \
    Dependencies/SideSign/Sources/Models/Feature.swift \
    Dependencies/SideSign/Sources/Models/Entitlement.swift \
    Dependencies/SideSign/Sources/CodeSigning/SigningEntitlements.swift \
    zLoader/Tests/ManagedSigningTests.swift -o .build/ManagedSigning/tests
.build/ManagedSigning/tests
