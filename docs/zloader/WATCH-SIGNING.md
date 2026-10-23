# Watch signing and refresh

zLoader signs the complete phone/Watch bundle graph. The original source component
identifiers stay unchanged during customization. Resigning resolves every component's
final identifier from its matching profile before writing any identity metadata.

For a phone renamed from `example.app` to `example.app.TEAM`, the Watch app's
`WKCompanionAppBundleIdentifier` becomes `example.app.TEAM`. Nested legacy Watch
extensions also get a matching `NSExtensionAttributes.WKAppBundleIdentifier`.
Direct phone extensions, Watch apps, and their nested extensions receive separate
profiles and entitlement dictionaries. Frameworks do not inherit host permissions.

## Apple-account provisioning

The Watch must already be registered in the selected Apple team. zLoader's device
management screen can register a Watch using its actual UDID. The phone's UDID does
not authorize the Watch, and the local phone installation transport does not discover
or register its paired Watch automatically.

Before creating App IDs or profiles for a Watch-containing IPA, zLoader checks for
eligible registered Watch devices. Managed Watch profiles include those devices;
phone profiles retain the phone's existing validation and optional sharing-device
behavior. Free-team automatic profiles remain supported and must authorize a
registered Watch. Apple uses the same
[iOS development profile family for iOS and watchOS](https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile/)
and supports Watch devices in
[Ad Hoc profiles](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/).

## Imported profiles

Imported installation validates every component's team, certificate, expiry, bundle
identifier and entitlements. A Watch profile must be device-scoped. Without an Apple
account session or a paired-Watch UDID, zLoader cannot prove that the profile contains
the actual paired Watch; iOS/watchOS performs that device check during installation.
The phone's UDID is not substituted for the missing Watch identity. Imported sign-only
exports retain their existing behavior: they do not target the local phone or Watch.

## Refresh and metadata

A Watch-containing app refresh uses the existing full resign/reinstall pipeline.
Phone-only profile injection cannot establish that a Watch's embedded profile was
renewed. Original and signed components are matched by paths relative to the package
root, so two extensions named `Extension.appex` cannot overwrite each other's identity. Profile expiry and
cached metadata include Watch components. Generated team suffixes and cached Watch
references do not become the next operation's source identity.

## Local validation

```sh
sh zLoader/scripts/test-watch-signing.sh
sh zLoader/scripts/test-watch-signing.sh /path/to/full-Clawy-resignable.ipa
sh zLoader/scripts/test-embedded-profile-reuse.sh
sh zLoader/scripts/test-managed-signing.sh
sh zLoader/scripts/build-unsigned.sh
```

The optional real Clawy fixture covers its four components: the phone app, Share
extension, Live Activity widget and modern Watch app. Synthetic layouts cover nested
legacy Watch extensions and duplicate extension filenames. Additional checks cover
cached identities from a previous team, exact references and background task IDs.

On 2026-10-23 the real Clawy layout test, focused profile/signing/transport checks and
the complete iPhoneOS build passed. Apple `codesign` decoded and verified the pinned
signer's synthetic DER-entitlement regression output. The generated zLoader IPA is
resignable and contains no Apple provisioning profiles or private signing keys.
No live Apple account/profile mutation or paired-Watch installation was performed.
Build and synthetic-signature checks are not hardware installation proof.
