#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/ImportedSigningSelection
# SideSign types are supplied by credential-free store fixtures on macOS.
sed '/^import SideSign$/d' zLoader/Features/Core/Signing/SigningIdentityStore.swift > .build/ImportedSigningSelection/SigningIdentityStore.swift
swiftc -module-cache-path .build/ImportedSigningSelection/ModuleCache \
    .build/ImportedSigningSelection/SigningIdentityStore.swift \
    zLoader/Tests/ImportedSigningSelectionTests.swift -o .build/ImportedSigningSelection/tests
.build/ImportedSigningSelection/tests
