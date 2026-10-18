# Imported identities and source IPA downloads — 0.7.63

Apple login is optional. Onboarding can continue without an account. Import a
PKCS#12 certificate with its matching private key and Apple-signed provisioning
profiles in Settings → Signing Identities. Select the identity under Install &
Refresh. Saving an identity while signed out selects it automatically. A successful Apple login selects the original Apple Account workflow again.
References
are stored in preferences; private keys remain in the certificate Keychain store.

Installation, updates, re-signing and refresh use a snapshot of that selection.
No portal certificate, App ID or profile requests occur on the imported path.
Each component must have a valid profile authorizing its concrete bundle ID,
the selected certificate, this device and its required entitlements. A wildcard
profile can be reused for matching components when it grants all their rights.
It does not create explicit identifiers or additional permissions on Apple's
portal. Missing/deleted material produces an error, never an account fallback.

Imported refresh re-signs and reinstalls the cached application, rather than
injecting a profile for a different signing certificate. This requires the cached
app and the normal pairing/transport setup. It cannot extend the certificate or
profile expiry. Expired, revoked or incompatible material must be replaced;
local key/date validation alone cannot establish current portal revocation state.
Backup/helper installation also needs profiles authorizing those helper IDs.
The installed zLoader team and shared App Groups remain protected during self
updates; an unrelated team cannot replace that installation's identity.

Source app installation/update is enabled only after the source is added. The
round download button remains available on source previews and added sources.
It downloads the original IPA, validates HTTP/ZIP prefix and an advertised SHA256,
and opens Files export without adding a source, signing or Apple login.

Local validation: signing/entitlement, profile/device/certificate compatibility,
transport, account-policy, login and revocation regression scripts; source download
error/hash/filename/byte preservation tests; project configuration, Release device
build and IPA package checks. Actual Files UI, anonymous install/refresh, certificate
changes, App Group preservation and lifecycle/cellular behavior need hardware tests.
