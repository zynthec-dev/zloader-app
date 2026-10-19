#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache \
    zLoader/Features/Views/Settings/Advanced/CacheMgmt/IPAArchiveMetadata.swift \
    zLoader/Tests/IPAArchiveMetadataTests.swift -o .build/test-ipa-archive-metadata
.build/test-ipa-archive-metadata
