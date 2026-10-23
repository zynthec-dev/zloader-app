# Container settings navigation, zLoader 0.8.4

The embedded container settings previously displayed two navigation bars when
opening a detail such as Device Identity: the outer UIKit bar retained the
Container Settings title/back action while the embedded SwiftUI NavigationStack
added the detail's title/back action.

The container subtree now owns one visible SwiftUI navigation bar. Its root has a
single action returning to zLoader Settings; details use the standard stack back
action. The wrapper hides the outer UIKit bar while visible and restores its
previous state when leaving. A narrow block callback crosses the existing runtime
bridge without linking the embedded runtime against host app implementation.

The Multiple LiveContainers entry and its explanatory footer are no longer shown
in zLoader. The original standalone runtime keeps its own behavior and credits.
Multitasking within zLoader remains available.

The main Settings order is now Developer Options, Container Settings, User
Customizations, then Experimental Features. Container Settings and User
Customizations have been removed from their former Advanced Settings positions.
They remain available when extra diagnostics are hidden; tvOS retains User
Customizations without exposing the iOS-only container destination.

All 32 README local regression scripts passed. The iPhone 17 simulator UI
regression `test008SettingsOrderAndSingleBackNavigation` passed with zero failures
on iOS 27.0. It covers
row order, one root/detail navigation bar and back action, absence of the multiple
container entry, Device Identity and JIT-less diagnostic return paths, and access
to User Customizations. Exported screenshots were visually inspected and are
retained with the UI result.
The iPhoneOS Release build, bootstrap package check and strict signatures of the
normalized resignable IPA passed. Physical-device installation, Apple signing,
refresh and lifecycle have not been validated for this release. Public
feed/download verification is recorded separately in the release receipt.

Existing uncommitted localization changes are preserved and excluded from the
implementation commit. The corresponding-source archive includes the actual
localization source used for the build, with file hashes in its source manifest.
