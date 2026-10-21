#!/bin/sh
# Reviewable build artifact, not an entitlement-authorized installable release.
set -eu
cd "$(dirname "$0")/../.."
sh zLoader/scripts/apply-dependency-patches.sh
# Resolve first so dependency patches also apply on a clean checkout.
xcodebuild -resolvePackageDependencies -project zLoader.xcodeproj -scheme zLoader \
  -clonedSourcePackagesDirPath .build/SourcePackages -skipPackageUpdates
sh zLoader/scripts/apply-dependency-patches.sh
sh zLoader/scripts/prepare-patched-idevice.sh ios
xcodebuild -project zLoader.xcodeproj -scheme zLoader -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath .build/Device \
  -clonedSourcePackagesDirPath .build/SourcePackages -disableAutomaticPackageResolution \
  -skipPackageUpdates CODE_SIGNING_ALLOWED=NO \
  MAIN_BUNDLE_IDENTIFIER=com.zynthec.zLoader \
  APP_GROUP_IDENTIFIER=com.zynthec.zLoader build
python3 zLoader/scripts/package-unsigned.py
python3 zLoader/scripts/package-resignable.py
