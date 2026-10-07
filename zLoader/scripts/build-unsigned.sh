#!/bin/sh
# Reviewable build artifact, not an entitlement-authorized installable release.
set -eu
cd "$(dirname "$0")/../.."
sh zLoader/scripts/apply-dependency-patches.sh
xcodebuild -project zLoader.xcodeproj -scheme zLoader -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath .build/Device \
  -clonedSourcePackagesDirPath .build/SourcePackages CODE_SIGNING_ALLOWED=NO \
  MAIN_BUNDLE_IDENTIFIER=com.zynthec.zLoader \
  APP_GROUP_IDENTIFIER=com.zynthec.zLoader build
python3 zLoader/scripts/package-unsigned.py
python3 zLoader/scripts/package-resignable.py
python3 zLoader/scripts/package-unsigned.py --internal
python3 zLoader/scripts/package-resignable.py --internal
