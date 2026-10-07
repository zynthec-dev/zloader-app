# Portal bulk actions, 0.7.32

The selection screen has an always-visible destructive action above the tab bar,
using a SwiftUI safe-area inset rather than a bottom toolbar in the UIKit host.
Select All now produces **Delete All** (or **Revoke All** for certificates), with
the selected resource count. Empty lists cannot toggle a misleading all-selected
state. Partial selections retain Delete Selected / Revoke Selected.

Confirmation still occurs before any portal mutation. The existing per-resource
DeveloperServicesViewModel operations call DeveloperPortalProxy / Apple's API.
The batch processes a stable snapshot of selected IDs sequentially, continues
past failed resources, and retains failed selections and their error messages.
App IDs, App Groups, profiles and device deletions use the existing post-mutation
portal readback. Certificate revocation uses Apple's mutation response. The
progress display now reports processed items out of the confirmed batch size.

This is a feature implementation, not authorization to clear the current user's
portal during validation. No live resources were deleted or revoked as a test.
Apple may reject a deletion due to dependent resources or team restrictions;
such errors are reported rather than represented as successful local deletion.

Transport, App Group, context and Settings storyboard checks passed. Release
build/package verification is separate from physical UI and Apple portal tests.
