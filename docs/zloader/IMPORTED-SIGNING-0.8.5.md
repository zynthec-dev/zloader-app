# Imported signing and app actions, zLoader 0.8.5

Signing Method now always offers Apple Account and Imported Certificate. The
imported option is visible before any identity has been saved, including when no
Apple account is signed in. A direct link opens the certificate/profile editor;
existing local certificates with matching profiles can be selected there, and
PKCS#12 certificates with private keys and additional profiles can be imported.
The editor proposes matching unexpired profiles and a certificate-based name.
Saving returns the identity to the sign-only screen without selecting Apple
Account implicitly.

Signing Identities is also available in Settings without an account. Its
Install & Refresh method persists separately from the identity reference. An
unconfigured or removed imported identity fails with an actionable error rather
than falling through to Apple login. Existing identity selections migrate to the
imported method; choosing Apple Account explicitly clears the imported operation
selection. Signing UI owns one SwiftUI navigation stack, so import, identity and
profile destinations work when opened from the UIKit shell.

The signing engine still validates private-key material, certificate/profile
matching, team, expiry, each bundle ID and profile-authorized entitlements.
Wildcard profiles use the existing profile-matching path; they do not create new
Apple permissions. Install/refresh additionally validates the receiving device.
No Apple portal session is required for the imported signing path. Sign-only and
Install & Refresh retain separate explicit selections.

My Apps places Add at the leading edge and Sign at the trailing edge. Switching
back from Containers restores both actions. Tab icons use a consistent set of
SF Symbols: text bubble, source stack, compass, app grid and sliders. The Add
menu, URL input and installation confirmation use the new AppActions string
catalog with German translations and English fallback. Existing user edits in
Localizable.xcstrings remain untouched and outside the implementation commit.

All 33 README local regression scripts passed, including the isolated
store-selection test with credential-free fixtures. The iPhone 17 simulator
regression `test009OfflineSigningAndLocalizedAppActions` passed on iOS 27.0;
exported screenshots were visually inspected. Release validation also checks
the iPhoneOS build, bootstrap package and strict resignable IPA integrity.
The store test covers method
persistence, initial empty imported selection, identity activation, removed
identity rejection and legacy migration. Existing managed-signing checks cover
wildcard expansion and rejection of unauthorized entitlements. Simulator checks
cover toolbar placement, German menu labels, both signing methods before import,
editor navigation and account-independent Settings access. Public asset/feed
verification is recorded in the release receipt.

Actual Apple-issued certificate/profile signing and installation on physical
hardware, device refresh, JIT and cellular lifecycle are not established by these
local checks. They remain device validation work for this release.
