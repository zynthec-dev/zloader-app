# Private Apple-signed IPA: 0.7.5

On 2026-10-06 a Release IPA was built with the existing local Xcode installation's
bundle IDs/App Groups and original Apple Development keychain identity. It
contains the host, every current extension (Widget and Tunnel), and a separately
signed embedded zLoaderBackup IPA. Each app/extension has its own unchanged Apple
provisioning profile and the complete signed entitlements from its corresponding
Xcode product. No private key was exported or embedded.

The existing Xcode Debug IDs differ from the default Release IDs. The signed
artifact deliberately uses the installed Xcode identities rather than changing
containers. The ordinary unsigned artifacts retain the default Release identity.
All signed outputs/profile-bearing staging files are ignored by Git and remain
local; no signed artifact/profile was uploaded to GitHub or the public source.

## Build and validate

A matching signed Xcode Debug host plus signed Backup product, valid profiles and
an available original keychain signing identity are prerequisites. A single
matching DerivedData product is selected by default; otherwise pass
`--reference-app /path/to/zLoader.app`.

```sh
python3 zLoader/scripts/package-apple-signed.py
python3 zLoader/scripts/verify-signed-ipa.py outputs/zLoader-0.7.5-Apple-signed.ipa
python3 zLoader/scripts/resign-preserving-profiles.py outputs/zLoader-0.7.5-Apple-signed.ipa \
  --output outputs/zLoader-0.7.5-Apple-resigned.ipa
```

These commands use macOS codesign/security and the existing keychain identity.
The build creates no Apple account, certificate or profile. It builds unsigned
code using the reference identities, then signs dependencies, extensions, backup
and host with the real identity and original profiles. Profile expiry, certificate
membership, all signed entitlements, Apple-anchored nested seals, retained
extensions and shared App Group/tunnel declarations are checked. The reference
profiles also have a commonly registered device. Profiles and private identity
information are not written into tracked files.

## In-app re-signing

zLoader reuses compatible embedded profiles for its own host/extensions when
bundle ID, team, original signing certificate DER, expiration, device eligibility
and required App Group/Network Extension values match. An unsigned update can
use a compatible profile from the running installation. Original own-app IDs are
kept when signing with their original certificate. Each extension is evaluated
separately. If a profile is incompatible or device identity cannot be confirmed,
the normal Apple provisioning path remains active, with its authorization checks.
Explicit user-selected override profiles continue to use the override path.

The same certificate alone is insufficient: the matching private key must be
available to the signer and the profiles must remain current, device-authorized
and capable. The IPA does not contain that private key. An arbitrary third-party
importer may replace profiles/entitlements; these scripts and zLoader's own
policy cannot force another signer to preserve them.

## Evidence and boundaries

- Release normal-ID build and Xcode-ID Release build: PASS, zero warnings/errors.
- arm64 Simulator Debug build: PASS, zero warnings/errors.
- All existing harnesses and new profile-reuse policy harness: PASS. Policy tests
  use synthetic certificate/device fixtures, not a real Apple account.
- Final Apple-signed host, Widget, Tunnel and Backup: PASS current profile and
  signing-certificate authorization; complete signed entitlements preserved.
- Second local Apple signing with the same original certificate: PASS all
  entitlement dictionaries identical and every embedded profile byte-identical.
- Physical installation of this IPA, in-app/live-account self-refresh, certificate
  revocation status, real pairing and cellular operation: not tested here.

Original IPA SHA-256:
`acea8139eca37a94340f478048c23c8615dda48aabe7acf1dabbe51b8c372ce7`.
Second signed IPA SHA-256:
`adc38d566cb593cc28a2cac4c10a18a04575a46496d75eb6525ef3ffb66fe59a`.

Install/update with the current Xcode identities preserved; retain all extensions
and do not delete the existing app as a repair step. Development installation is
limited to devices authorized by these profiles. Validate launch, Settings,
Pairing and self-refresh on the intended iPhone before claiming runtime success.

## Complete resignable variant, 2026-10-06

```sh
python3 zLoader/scripts/package-resignable.py \
  --signed-ipa outputs/zLoader-0.7.5-Apple-signed.ipa
```

Output: `outputs/zLoader-0.7.5-resignable.ipa`; latest resignable/iLoader aliases
are updated to this same artifact. It contains the host, Widget, Tunnel and the
embedded Backup IPA with all original entitlement values and byte-identical
Apple profiles. Each bundle is locally ad-hoc signed as import metadata; this
variant must be properly Apple re-signed before installing. It is distinct from
the original Apple-signed IPA, which remains unchanged.

Validation passed for nested ad-hoc seals, ZIP integrity, full entitlement
comparison, original profile-byte preservation, and XML CSSLOT_ENTITLEMENTS in
host, both extensions and Backup. Input profiles/signatures were fully checked
before creating this variant. The output correctly fails the final Apple-anchor
check; its attached profiles do not make an ad-hoc signature Apple-authorized.
A receiving signer must retain the profiles or supply matching, equally capable
profiles and the corresponding private key. iLoader/other importers may replace
these; this package cannot force their behavior.

SHA-256:
`138cf2b0142e30ddae10de89285e1213638746277d259e57a676f170da192750`.
No physical installation or in-app refresh of this variant was run.

## Updated pairing branding: 0.7.6

The 0.7.6 Apple-signed and complete resignable variants carry the corrected client
and server host name. Their Xcode identities, all extensions, embedded Backup,
profiles and complete entitlements remain preserved. Use the versioned 0.7.6
outputs for new pairing attempts; the generic resignable/iLoader aliases also
point to the new complete resignable output. Hashes and build evidence are in
[VALIDATION.md](VALIDATION.md). No physical pairing session was performed here.
