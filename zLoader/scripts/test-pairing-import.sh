#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/PairingTests .build/SwiftModuleCache
swiftc -module-cache-path .build/SwiftModuleCache -emit-module -emit-library -module-name MinimuxerCommon \
  Dependencies/minimuxer/Common/PairingFile.swift Dependencies/minimuxer/Common/PairingProtocol.swift \
  Dependencies/minimuxer/Common/ConcurrencyUtils.swift Dependencies/minimuxer/Common/MinimuxerConstants.swift \
  -emit-module-path .build/PairingTests/MinimuxerCommon.swiftmodule -o .build/PairingTests/libMinimuxerCommon.dylib
swiftc -module-cache-path .build/SwiftModuleCache -I .build/PairingTests -L .build/PairingTests \
  -lMinimuxerCommon -Xlinker -rpath -Xlinker "$PWD/.build/PairingTests" \
  zLoader/Features/Core/Pairing/PairingFileManager.swift zLoader/Tests/PairingImportTests.swift \
  -o .build/PairingTests/pairing-import-tests
.build/PairingTests/pairing-import-tests
