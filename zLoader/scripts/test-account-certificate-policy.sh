#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/AccountCertificatePolicy
swiftc -module-cache-path .build/AccountCertificatePolicy/ModuleCache \
    zLoader/Features/Core/Certificates/AccountCertificatePolicy.swift \
    zLoader/Tests/AccountCertificatePolicyTests.swift -o .build/AccountCertificatePolicy/tests
.build/AccountCertificatePolicy/tests
