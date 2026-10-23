#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
for spec in 'minimuxer:minimuxer-warnings.patch' 'SideSign:sidesign-managed-signing.patch'; do
    dependency=${spec%%:*}
    patch="$PWD/zLoader/Patches/${spec#*:}"
    # The Mac Anisette upgrade overlaps the cumulative authentication hunks.
    # Its reverse check confirms the newer state; do not reapply the baseline.
    if [ "$dependency" = SideSign ] && git -C Dependencies/SideSign apply --reverse --check "$PWD/zLoader/Patches/sidesign-mac-anisette.patch" 2>/dev/null; then
        continue
    fi
    if git -C "Dependencies/$dependency" apply --reverse --check "$patch" 2>/dev/null; then
        continue
    fi
    # Upgrade an existing checkout carrying the previous cumulative patch set.
    if [ "$dependency" = minimuxer ]; then
        upgrade="$PWD/zLoader/Patches/minimuxer-self-submission.patch"
        if git -C "Dependencies/$dependency" apply --check "$upgrade" 2>/dev/null; then
            git -C "Dependencies/$dependency" apply "$upgrade"
            git -C "Dependencies/$dependency" apply --reverse --check "$patch"
            continue
        fi
    fi
    if [ "$dependency" = SideSign ]; then
        for name in sidesign-managed-capabilities.patch sidesign-watch-signing-upgrade.patch; do
            upgrade="$PWD/zLoader/Patches/$name"
            if git -C "Dependencies/$dependency" apply --check "$upgrade" 2>/dev/null; then
                git -C "Dependencies/$dependency" apply "$upgrade"
            fi
        done
        if git -C "Dependencies/$dependency" apply --reverse --check "$patch" 2>/dev/null; then
            continue
        fi
    fi
    git -C "Dependencies/$dependency" apply --check "$patch"
    git -C "Dependencies/$dependency" apply "$patch"
done

# The upgrade check also handles checkouts with the previous portal patch.
upgrade="$PWD/zLoader/Patches/sidesign-portal-signing-activation.patch"
if ! git -C Dependencies/SideSign apply --reverse --check "$upgrade" 2>/dev/null; then
    patch="$PWD/zLoader/Patches/sidesign-portal-capabilities.patch"
    if ! git -C Dependencies/SideSign apply --reverse --check "$patch" 2>/dev/null; then
        git -C Dependencies/SideSign apply --check "$patch"
        git -C Dependencies/SideSign apply "$patch"
    fi
    git -C Dependencies/SideSign apply --check "$upgrade"
    git -C Dependencies/SideSign apply "$upgrade"
fi

patch="$PWD/zLoader/Patches/sidesign-mac-anisette.patch"
if ! git -C Dependencies/SideSign apply --reverse --check "$patch" 2>/dev/null; then
    git -C Dependencies/SideSign apply --check "$patch"
    git -C Dependencies/SideSign apply "$patch"
fi

patch="$PWD/zLoader/Patches/sidesign-extensionkit.patch"
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
