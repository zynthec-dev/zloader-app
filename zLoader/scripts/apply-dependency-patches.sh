#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
patch="$PWD/zLoader/Patches/minimuxer-warnings.patch"
if git -C Dependencies/minimuxer apply --reverse --check "$patch" 2>/dev/null; then
    exit 0
fi
git -C Dependencies/minimuxer apply --check "$patch"
git -C Dependencies/minimuxer apply "$patch"
