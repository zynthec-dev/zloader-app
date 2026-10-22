#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
build=.build/ContainerTests
mkdir -p "$build"
xcrun --sdk macosx clang -fobjc-arc -fblocks -Wall -Wextra -framework Foundation \
    Vendor/LiveContainer/LiveContainer/Tweaks/ZLoaderGuestURLPolicy.m \
    zLoader/Tests/ContainerGuestURLPolicyTests.m -o "$build/url-tests"
"$build/url-tests"
swiftc -module-cache-path "$build/ModuleCache" \
    Vendor/LiveContainer/LiveContainerSwiftUI/Models/LCVirtualDeviceIdentity.swift \
    zLoader/Tests/ContainerDeviceIdentityTests.swift -o "$build/identity-tests"
"$build/identity-tests"
xcrun --sdk macosx clang -fobjc-arc -fblocks -Wall -Wextra -framework Foundation -larchive \
    Vendor/LiveContainer/LiveContainerSwiftUI/Utilities/unarchive.m \
    zLoader/Tests/ContainerArchiveTests.m -o "$build/archive-tests"
python3 - <<'PY'
from pathlib import Path
import subprocess, tempfile, zipfile
runner=Path('.build/ContainerTests/archive-tests').resolve()
with tempfile.TemporaryDirectory() as folder:
    root=Path(folder)
    fixtures=[('valid', [('Payload/Test.app/Info.plist', b'fixture', False)], True),
              ('traversal', [('../outside', b'bad', False)], False),
              ('absolute', [('/tmp/outside', b'bad', False)], False),
              ('symlink-escape', [('Payload/link', b'../../outside', True)], False),
              ('absolute-link', [('Payload/link', b'/tmp', True)], False),
              ('symlink-internal', [('Payload/Test.app/real', b'fixture', False),
                                    ('Payload/Test.app/link', b'real', True)], True)]
    for name, entries, succeeds in fixtures:
        ipa=root/(name+'.ipa')
        with zipfile.ZipFile(ipa,'w') as archive:
            for path,data,link in entries:
                entry=zipfile.ZipInfo(path);entry.create_system=3
                entry.external_attr=((0o120777 if link else 0o100644)<<16)
                archive.writestr(entry,data)
        subprocess.run([str(runner),str(ipa),str(root/name/'out'),str(int(succeeds))],check=True)
    assert not (root/'outside').exists()
print('PASS isolated IPA extraction, path traversal, absolute paths, escaping links, valid internal links')
PY
