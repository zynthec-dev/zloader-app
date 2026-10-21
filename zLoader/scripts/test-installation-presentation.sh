#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/InstallationPresentation
swiftc -module-cache-path .build/InstallationPresentation/ModuleCache \
    zLoader/Features/Core/Operations/AppInstallationPresentation.swift \
    zLoader/Tests/AppInstallationPresentationTests.swift -o .build/InstallationPresentation/tests
.build/InstallationPresentation/tests
