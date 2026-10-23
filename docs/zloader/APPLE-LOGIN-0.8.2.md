# Apple login compatibility, zLoader 0.8.2

Apple's recent GrandSlam changes reject the previous Android/Windows ADI login
path with -80046. Installation with iLoader does not establish an authenticated
Apple session inside zLoader. The app previously forced an Android descriptor for
SRP even if its Anisette provider used a different device identity.

Version 0.8.2 uses `https://mac-ani.jkcoxson.com` by default, matching the current
iLoader and xtool provider. The first startup/fetch after upgrading disables the
old on-device default and automatic rotation, selects the Mac server and retains
account, app and pairing records. This migration runs once; later manual settings
changes and hidden server choices remain respected. A built-in catalog entry
makes the server available even when the remote server list is unavailable.
Existing custom server entries remain available.

The server's V3 `client_info` response supplies Client-Info and User-Agent for
provisioning, GrandSlam SRP and 2FA. The 16 UUID bytes are Base64 encoded for both
V3 HTTP and WebSocket requests. Device ID and local-user hash match that UUID;
routing information comes from the server's OTP response. ADI blobs are tagged
with their provider in Keychain and are not reused across server changes or when
switching between remote and on-device Anisette. Unidentified legacy remote blobs
are provisioned afresh. A failed V3 request cannot silently use a shared V1
identity. Login retry retains the provider identity and does not restart after an
accepted pushed 2FA code. Credentials and verification codes are sent to Apple;
the Anisette service receives only the provisioning data and random device ID.

The SideSign gitlink is unchanged. `sidesign-mac-anisette.patch` applies after the
existing managed-signing and portal patches; the application script recognizes
both the previous state and this upgraded state idempotently. Original credits
remain in the source archive.

## Installation

Install the resignable 0.8.2 IPA with iLoader over the existing installation,
using the same Apple account and app identity. Do not delete zLoader to apply this
fix. Open it and try Apple sign-in again, including the 2FA code if requested. No
manual Anisette settings edit or pairing reset is needed for the default path.
If Anisette was changed manually after the migration, select Mac Anisette
(jkcoxson) and turn off On-Device Anisette.

## Validation

The README regression scripts, dedicated provider-identity/retry tests, server
migration tests and real-provider HTTP mock tests cover UUID encoding, matching
identity, server routing, explicit custom/hidden choices and rejection of failed
V3 responses without a V1 fallback. The iPhoneOS Release build and strict resignable
IPA checks are required before publication. Patch application is checked on a
clean dependency tree and repeated on the current checkout.

A successful build or protocol test does not prove Apple-account authentication
on an iPhone. Actual Apple login/2FA, portal access, iLoader replacement, refresh,
self-update and lifecycle/cellular behavior still require physical-device testing.

References: [iLoader default provider](https://github.com/nab138/iloader/commit/9025975),
[xtool Mac Omnisette migration](https://github.com/xtool-org/xtool/pull/380),
[Omnisette V3 server](https://github.com/SideStore/omnisette-server).
