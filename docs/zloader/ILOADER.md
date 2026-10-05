# Installing through iLoader

Use `outputs/zLoader-iLoader.ipa`. This artifact contains local ad-hoc signatures
solely to preserve explicit capability declarations in the Mach-O entitlements.
It has no Apple installation signature and must be re-signed. The separate
fully unsigned artifact remains available for inspection/custom signing.

The packaging script reads the target entitlement files rather than maintaining
separate duplicate capability dictionaries. It checks both decoded entitlements
and the XML Mach-O slot, shared group identity, nested seals and ZIP integrity.

| Bundle | Declared requirement |
| --- | --- |
| zLoader | `group.com.zynthec.zLoader` and `packet-tunnel-provider` |
| zLoaderWidget | `group.com.zynthec.zLoader` |
| zLoaderTunnel | `packet-tunnel-provider` |

No team, device identifier, certificate or private key is fabricated or bundled.
The tunnel does not use shared database storage, so it needs no App Group.

## Verified iLoader behavior and limitation

On 2026-10-05 the official iLoader checkout was inspected at
`f322733dc60d191c6d82df9dc70d26e3548e38f8`. Its Cargo.lock pins `isideload` 0.4.0;
the published crate was checked against SHA-256
`ec15f715854513ea29c71ac061dcfd6e053ccda71dc5e39e5145d22d32299343`.

The generic IPA signing path:

1. Appends the selected team identifier to the main bundle ID and updates extensions.
2. Registers one group derived from that signed bundle ID and assigns it to all App IDs.
3. Downloads profiles and uses **their** entitlement dictionaries for signing the
   host and extensions. Incoming IPA entitlements are not the authority.

The runtime App Group resolver already supports this renamed, actually accessible
group. No SideStore identity spoofing or iLoader-specific special-app marker is used.
The generic path does not inject SideStore's certificates/pairing file into zLoader;
use zLoader's own login and pairing-import flow as needed.

The inspected `isideload` path enables App Groups, but has no automatic step to
request Network Extension. Adding an entitlement plist or ad-hoc signature to the
IPA does not change that. For this embedded tunnel the selected paid team's
**actual host and provider App IDs/profiles** must authorize
`com.apple.developer.networking.networkextension = [packet-tunnel-provider]`.
If iLoader's generated profiles omit it, the IPA alone cannot fix the limitation.
Use correctly configured Apple development signing/profiles rather than removing
capabilities or pretending an installation succeeded.

References:
- https://github.com/nab138/iloader/blob/f322733dc60d191c6d82df9dc70d26e3548e38f8/src-tauri/src/sideload.rs
- https://docs.rs/crate/isideload/0.4.0/source/src/sideload/sideloader.rs
- https://docs.rs/crate/isideload/0.4.0/source/src/sideload/sign.rs

## Check the signed result

Retain all extensions. For an update, preserve the actual installed bundle ID/team
and App Group identity; do not delete the existing app as a repair step.

If the final iLoader-signed IPA is available, run on macOS:

```sh
python3 zLoader/scripts/verify-signed-ipa.py /path/to/iloader-signed.ipa
```

This reads the IPA without changing it. It checks an Apple-anchored code signature,
retained extensions, host/widget shared group, host/provider tunnel entitlements,
matching bundle identities/teams and authorization of those capabilities by each
embedded provisioning profile. An ad-hoc artifact must fail this final-install check.

This is not a device acceptance test. Profile expiry, registered-device eligibility,
VPN consent, actual container access, pairing, cellular-only install/refresh and
physical launch remain to be tested on the iPhone. No Apple account/device was used
for the local build and package verification.
