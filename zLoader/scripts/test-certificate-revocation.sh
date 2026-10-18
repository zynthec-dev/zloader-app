#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/CertificateRevocation
# External imports and access levels are adjusted for the standalone harness.
# All production control flow is compiled unchanged against fixture types.
sed -e '/^import CodeSignKit$/d' -e 's/^public extension DeveloperPortal/extension DeveloperPortal/' Dependencies/SideSign/Sources/DeveloperPortal/Certificates.swift > .build/CertificateRevocation/Certificates.swift
swiftc -module-cache-path .build/CertificateRevocation/ModuleCache \
    .build/CertificateRevocation/Certificates.swift zLoader/Tests/CertificateRevocationTests.swift \
    -o .build/CertificateRevocation/tests
.build/CertificateRevocation/tests
