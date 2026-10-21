# Managed capabilities and re-signing

The signer uses only capabilities requested by the app or explicit customization.
It does not add every right granted to the developer account. Apple approval and
activation for the actual re-signed App ID are prerequisites for managed rights.

For Apple-account signing, known services use their legacy Developer Services
identifiers. Other nonempty `com.apple.developer.*` requests, excluding team
identity, are sent individually as typed managed entitlement requests. One
capability rejection does not suppress other requests. Authentication, rate-limit
and transport failures still stop the operation. APIs may not support enabling
all managed rights: activate those in Apple's portal for the actual App ID.
The newly issued Apple-signed profile is always authoritative.

A downloaded existing profile is reusable only if it authorizes the entire
request as well as the selected team, certificate and devices. Otherwise zLoader
renews an owned profile or creates one before considering optional omissions.
This discovers approvals made after the previous signing operation. Unsupported
optional rights retain the existing omission policy after issuance; CarPlay
rights cannot be silently omitted. A missing CarPlay grant stops signing with an
entitlement diagnostic. Imported identity/profile signing remains read-only and
requires a compatible supplied profile.

Original `cyan.entitlements` sidecar requests survive an earlier signing pass
that omitted unapproved rights. Actual signed values take precedence over sidecar
values. Sidecar data is never authorization: all resulting requests still pass
profile validation, identity remapping and least-privilege signing.

CodeSignKit emits canonical, versioned DER entitlements, with key-ordered
context-specific dictionaries and canonical booleans. A regression fixture is
compared byte-for-byte with Apple's encoder, then independently read and verified
with macOS `codesign`. The pinned dependency revisions are unchanged.

## Validation limits

Local tests cover request construction, original metadata preservation, profile
authorization and DER signing. They do not prove that Apple's live API enables a
specific account's managed capability. After installation, re-sign YouTube Music
and check that both `embedded.mobileprovision` and the actual signed entitlements
include `com.apple.developer.carplay-audio = true`. Physical CarPlay testing is
still required.

The supplied YouTube Music IPA passed `codesign --verify --deep --strict` when
macOS trust services were accessible. Earlier entitlement/trust diagnostics in
the restricted execution sandbox were false positives, not a broken certificate
chain. Its actual confirmed defect was missing CarPlay authorization in both
profile and signature.
