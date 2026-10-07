#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
for spec in 'minimuxer:minimuxer-warnings.patch' 'SideSign:sidesign-managed-signing.patch'; do
    dependency=${spec%%:*}
    patch="$PWD/zLoader/Patches/${spec#*:}"
    if git -C "Dependencies/$dependency" apply --reverse --check "$patch" 2>/dev/null; then
        continue
    fi
    git -C "Dependencies/$dependency" apply --check "$patch"
    git -C "Dependencies/$dependency" apply "$patch"
done
