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

## Pairing transfer (0.7.8)

The [official iLoader implementation](https://github.com/nab138/iloader/blob/main/src-tauri/src/pairing.rs)
combines Lockdown and Remote Pairing credentials in one property list. zLoader now
accepts the combined file and preserves both available protocols. Remote-only and
Lockdown-only files remain supported, including binary plists. Existing selected
protocols are respected when available; Remote Pairing is the default when no
selection is available. A stale Lockdown selection no longer prevents a remote-only
file from being loaded.

Import the exported file through zLoader's pairing-file picker, or transfer it into
zLoader's Documents folder using Files/File Sharing. Recognized incoming names:
`ALTPairingFile.mobiledevicepairing`, `pairingFile.plist`, `rp_pairing_file.plist`.
On each app boot, valid transferred data is stored in the canonical files for every
contained protocol. Source files are consumed only after a successful import;
invalid input is kept. On-device wireless pairing creates Remote Pairing credentials;
it does not manufacture a Lockdown certificate/private-key record.

The official iLoader GUI currently filters destinations with a hardcoded app-name
allowlist that excludes zLoader. This cannot be changed by zLoader's own IPA.
`zLoader/Patches/iloader-zloader-pairing.patch` adds zLoader to that allowlist and
its SideStore-style destination lookup, retaining all other apps. Applying the
patch to iLoader and rebuilding enables direct placement to
`Documents/ALTPairingFile.mobiledevicepairing`. The patch was checked against the
read-only fetched iLoader source, but a patched iLoader binary was not built or
installed. With the official binary, export/import is the supported path.

No actual pairing records or keys are included in this repository. Pairing import
regressions use synthetic, nonfunctional values; successful parsing does not prove
trust authorization or device-service access on hardware.

## StikPair and SideInstaller destinations

zLoader declares Pairing File document handling for property lists, XML and the
legacy mobiledevicepairing UTI, in addition to IPA handling. StikPair's current
[Export Pairing File](https://github.com/StikDebug/StikPair/blob/main/App/ContentView.swift)
uses the iOS share sheet. zLoader can therefore be offered as an Open-In destination
once iOS registers the installed app's document types. Actual share-sheet placement
on the user's phone remains a runtime check; declaring the type does not promise
that every share sheet immediately refreshes its cached choices.

SideInstaller's [PairingTargets](https://github.com/FrizzleM/SideInstaller/blob/main/ios-app/PairingTargets.swift)
is a fixed display-name table. `sideinstaller-zloader-pairing.patch` adds zLoader
and gives it the standalone AltStore-family handoff conversion and Documents path.
The patched target matching was compiled and tested locally with original,
team-suffixed and customized bundle IDs; existing SideStore discovery was preserved.
Neither patch was submitted upstream, and the official external applications have
not been changed. Direct automatic destination lists require the respective app
to integrate the patch. These are integration artifacts for the user's private
setup, not claims of endorsement or released upstream support.

Opening a pairing file through zLoader imports every contained protocol and starts
reloading the selected transport. An import can succeed while device connection
fails; that failure is shown separately. Pairing keys are never put in URL query
parameters or sent to a server.
