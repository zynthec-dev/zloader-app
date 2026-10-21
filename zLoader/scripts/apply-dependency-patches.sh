#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
for spec in 'minimuxer:minimuxer-warnings.patch' 'SideSign:sidesign-managed-signing.patch'; do
    dependency=${spec%%:*}
    patch="$PWD/zLoader/Patches/${spec#*:}"
    if git -C "Dependencies/$dependency" apply --reverse --check "$patch" 2>/dev/null; then
        continue
    fi
    # Upgrade an existing checkout carrying the previous cumulative patch set.
    if [ "$dependency" = SideSign ]; then
        upgrade="$PWD/zLoader/Patches/sidesign-managed-capabilities.patch"
        if git -C "Dependencies/$dependency" apply --check "$upgrade" 2>/dev/null; then
            git -C "Dependencies/$dependency" apply "$upgrade"
            continue
        fi
    fi
    git -C "Dependencies/$dependency" apply --check "$patch"
    git -C "Dependencies/$dependency" apply "$patch"
done

patch="$PWD/zLoader/Patches/sidesign-portal-capabilities.patch"
if ! git -C Dependencies/SideSign apply --reverse --check "$patch" 2>/dev/null; then
    git -C Dependencies/SideSign apply --check "$patch"
    git -C Dependencies/SideSign apply "$patch"
fi

# SwiftPM checkouts must be resolved before applying this runtime signing fix.
code_sign_kit="$PWD/.build/SourcePackages/checkouts/CodeSignKit"
if [ -d "$code_sign_kit" ]; then
    patch="$PWD/zLoader/Patches/codesignkit-der-entitlements.patch"
    if ! git -C "$code_sign_kit" apply --reverse --check "$patch" 2>/dev/null; then
        git -C "$code_sign_kit" apply --check "$patch"
        chmod u+w "$code_sign_kit/Sources/DEREncoder.swift"
        git -C "$code_sign_kit" apply "$patch"
    fi
fi
