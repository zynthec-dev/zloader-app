#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SourceIPAFile
swiftc -module-cache-path .build/SourceIPAFile/ModuleCache \
    zLoader/Features/Core/SourceDownloads/SourceIPAFile.swift zLoader/Tests/SourceIPAFileTests.swift \
    -o .build/SourceIPAFile/tests
.build/SourceIPAFile/tests
