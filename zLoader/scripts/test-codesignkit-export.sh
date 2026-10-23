#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
sh zLoader/scripts/apply-dependency-patches.sh
# Uses the actual pinned checkouts from a resolved Xcode build; no new dependencies.
root=$(pwd)
package="$root/.build/CertificateCompatibility"
mkdir -p "$package/Sources/CodeSignKit" "$package/Sources/Compatibility"
chmod -R u+w "$package/Sources"
cp .build/SourcePackages/checkouts/CodeSignKit/Sources/*.swift "$package/Sources/CodeSignKit/"
cp zLoader/Features/Core/Certificates/PortablePKCS12.swift zLoader/Tests/CodeSignKitExportTests.swift "$package/Sources/Compatibility/"
cp Dependencies/SideSign/Sources/Models/BundleSigningLayout.swift "$package/Sources/Compatibility/"
python3 - "$package" "$root" <<'PY'
import sys, json
from pathlib import Path
package, root = map(Path, sys.argv[1:])
crypto = json.dumps(str(root / '.build/SourcePackages/checkouts/swift-crypto'))
asn1 = json.dumps(str(root / '.build/SourcePackages/checkouts/swift-asn1'))
(package / 'Package.swift').write_text(f'''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "CertificateCompatibility", dependencies: [.package(path: {crypto}), .package(path: {asn1})], targets: [
.target(name: "CodeSignKit", dependencies: [.product(name: "Crypto", package: "swift-crypto"), .product(name: "CryptoExtras", package: "swift-crypto"), .product(name: "SwiftASN1", package: "swift-asn1")]),
.executableTarget(name: "Compatibility", dependencies: ["CodeSignKit"])
], swiftLanguageModes: [.v5])
''')
PY
work=$(mktemp -d /tmp/zloader-codesignkit-test.XXXXXX)
trap 'rm -rf "$work"' EXIT
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/private.pem" -out "$work/certificate.pem" -subj '/CN=zLoader Signing Parser Test' -days 1 > /dev/null 2>&1
openssl x509 -in "$work/certificate.pem" -outform DER -out "$work/certificate.der"
lipo /bin/echo -thin arm64e -output "$work/fixture"
SWIFTCI_USE_LOCAL_DEPS=1 swift run --package-path "$package" Compatibility "$work"

codesign -d --entitlements - --xml "$work/fixture" > "$work/decoded.plist" 2> "$work/diagnostics"
if rg -q 'invalid entitlements' "$work/diagnostics"; then cat "$work/diagnostics"; exit 1; fi
codesign --verify --strict "$work/fixture"
codesign --verify --deep --strict "$work/ExtensionKit.app"
codesign -d --entitlements - --xml "$work/ExtensionKit.app/Extensions/iOSHelper.appex" > "$work/helper-entitlements.plist" 2> "$work/helper-diagnostics"
python3 - "$work/helper-entitlements.plist" <<'PYHELPER'
import plistlib, sys
values = plistlib.load(open(sys.argv[1], 'rb'))
assert values['application-identifier'] == 'QA12345678.com.utmapp.UTM.QA12345678.iOSHelper'
assert values['test-owner'] == 'helper'
print('PASS Apple codesign verifies ExtensionKit signatures and the helper-specific identity/entitlements')
PYHELPER
python3 - "$work/decoded.plist" <<'PYTEST'
import plistlib, sys
values = plistlib.load(open(sys.argv[1], 'rb'))
assert values['com.apple.developer.carplay-audio'] is True
assert values['test-array'] == ['one', 'two']
print('PASS Apple codesign reads and verifies the generated DER signature without entitlement warnings')
PYTEST
