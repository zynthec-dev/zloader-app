#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p .build/LANInstaller
swiftc -module-cache-path .build/LANInstaller/ModuleCache \
    zLoader/Features/Core/Certificates/PortablePKCS12.swift \
    zLoader/Features/Core/LANInstaller/LANCertificate.swift \
    zLoader/Features/Core/LANInstaller/LANHTTP.swift \
    zLoader/Tests/LANInstallerTests.swift -o .build/LANInstaller/tests
.build/LANInstaller/tests .build/LANInstaller/fixtures

swiftc -module-cache-path .build/LANInstaller/ModuleCache \
    zLoader/Features/Core/Certificates/PortablePKCS12.swift \
    zLoader/Features/Core/LANInstaller/LANCertificate.swift \
    zLoader/Features/Core/LANInstaller/LANHTTP.swift \
    zLoader/Features/Core/LANInstaller/LANIPAServer.swift \
    zLoader/Tests/LANServerFixture.swift -o .build/LANInstaller/server-fixture
python3 zLoader/scripts/test-lan-server.py
