#!/bin/sh
# Reviewable build artifact, not an entitlement-authorized installable release.
set -eu
cd "$(dirname "$0")/../.."
sh zLoader/scripts/apply-dependency-patches.sh
xcodebuild -project zLoader.xcodeproj -scheme zLoader -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath .build/Device \
  -clonedSourcePackagesDirPath .build/SourcePackages CODE_SIGNING_ALLOWED=NO build
python3 zLoader/scripts/package-unsigned.py
python3 zLoader/scripts/package-resignable.py
