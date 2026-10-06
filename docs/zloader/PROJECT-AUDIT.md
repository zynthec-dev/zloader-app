# Project audit — zLoader 0.7.12

2026-10-06, Xcode 27.0, Apple Silicon. This is an independent private clone.
Original authors, licenses and the corresponding-source obligation remain intact.

## Xcode install, then in-app refresh

Keep the installed app, its exact bundle identity, App Group and developer team.
Do not delete the active host, Widget, Tunnel or Backup App IDs or their App Group.
Apple states that deleting an App ID invalidates its associated provisioning
profiles: [Delete an App ID](https://developer.apple.com/help/account/identifiers/delete-an-app-id/).
A new bundle ID or App Group can select new data containers. Removing unrelated,
unused IDs is separate from repairing this installation.

The ignored local `CodeSigning.xcconfig` currently preserves the previously
installed identity, including the duplicate suffix introduced by iLoader. That
suffix is retained deliberately to avoid switching containers. The application
and group identifiers must not be normalized while preserving this installation.
The public sample contains no account-specific configuration.

1. In Xcode Settings → Accounts, sign into the same paid developer team and use
   Manage Certificates to obtain a valid Apple Development certificate with its
   private key. Do not revoke other tools' certificates simply to clean the list.
2. Keep `CodeSigning.xcconfig` local. Its `MAIN_BUNDLE_IDENTIFIER` must match the
   installed host; `APP_GROUP_IDENTIFIER` is the existing group without `group.`.
3. Apply `sh zLoader/scripts/apply-dependency-patches.sh`, then open
   `zLoader.xcodeproj`, scheme `zLoader`, and select the iPhone.
4. Automatic Signing is configured for all four targets. Host and Tunnel require
   Network Extensions; Host, Widget and Backup use the same App Group. Let Xcode
   generate authorized profiles for the exact identities and device.
5. Install over the existing app. Keep both embedded extensions and the nested
   Backup package. Verify pairing and consent to the VPN configuration.
6. Refresh using the same developer team in zLoader. A different certificate is
   supported only with profiles authorizing that certificate, device, identifiers
   and all required entitlements. The in-app validator checks this before signing.

Automatic Signing cannot guarantee that Apple grants a capability. Merely copying
entitlements or retaining an old profile does not authorize a new certificate.
The pipeline preserves the installed identity and validates refreshed profiles;
physical refresh and self-replacement still require device acceptance.

## Cleanup and corrections

- One final local signing override, inherited team settings, explicit target
  entitlement files and parent-derived identifiers for Host/Widget/Tunnel/Backup.
  Tunnel now explicitly uses Automatic Signing and disables its debug dylib.
- Removed two unused obsolete entitlement files and dead cellular-shortcut
  constants/defaults. Existing device preferences and pairing files are untouched.
- Installer artifacts always use canonical base IDs, independently of the local
  configuration that preserves an already-installed app's data containers.
- Removed inherited linker `-w`. Earlier zero-warning logs concealed linker
  diagnostics. The pinned Unicorn and simulator Idevice binaries require iOS
  26.5; this build now declares that minimum rather than pretending compatibility
  with iOS 17. Older iOS support needs appropriately rebuilt dependencies.
- Updated deprecated text composition, UIKit list configurations, contextual
  screen access and URL callbacks. Scene URL delivery handles host imports;
  the SwiftUI Backup scene retains its URL handler. UI/device routing needs
  runtime verification after these changes.
- Refresh App Intent uses supported foreground modes instead of a fixed
  27-second timeout. Its completion follows the operation; synchronous startup
  errors now resume its continuation rather than leaving it suspended.
- Signed-IPA verification also checks the nested Backup package, its Apple
  signature/profile and team consistency. The unsigned installer remains an
  inspection/signing input, not a directly installable Apple-authorized IPA.

## Architecture and boundaries checked

App Group resolution requires a declared, accessible shared group and refuses a
private-database fallback. The Settings storyboard regression checks header
prototypes and outlet integrity. Provisioning validates team, certificate, device,
expiry, identity, groups and Network Extension permission, and does not bypass
Apple authorization. Same-team refresh preserves the running app identity.

The transport lease covers the operation pipeline and handles concurrent users,
cancellation, failure and teardown ordering. This establishes local lifecycle
logic, not cellular-only reliability on hardware. Remote and Lockdown pairing
imports handle combined records; legacy compatibility identifiers and original
author credits intentionally remain. The fixed source remains non-removable.

Dependency gitlinks were retained; Minimuxer's working-tree changes are the
tracked dependency patch. No portal records, installed data or local signing
artifacts were deleted. Unrelated user changes remain in the working tree.
Local self-signed exports can contain the runtime signing certificate payload;
they must remain private. No signed output is published by this audit.

## Validation and remaining limitations

See [VALIDATION.md](VALIDATION.md) for final build and test evidence.

At audit time the Mac reports **zero signing identities**, and Xcode reports
**No Accounts / no development certificate with a private key**. Consequently
0.7.12 cannot currently be Apple-signed or installed from this Mac. An older
0.7.11 signed recovery IPA passes the expanded package checker; that does not
establish current certificate validity at Apple's portal or new-device behavior.

The user confirmed refresh on 0.7.10. That result is distinct from verification
of 0.7.12. VPN consent, pairing, preserved database/widget access, cellular-only
install/refresh, self-replacement, cancellation and background termination need
physical acceptance. Light/Dark, accessibility, icons and shortcut foreground
transition also remain runtime checks.

The source endpoint returned HTTP 403 to this audit's direct request. The live
feed therefore could not be verified here; this does not establish failure in
all clients. No source deployment or access-control changes were made.
