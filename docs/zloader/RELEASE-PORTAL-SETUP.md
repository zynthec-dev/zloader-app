# Canonical Release identity

The project has one build configuration, `Release`. All shared schemes use it.
The app and its embedded extensions use these stable identifiers, without a
team ID appended to the bundle identifier:

| Portal description | Bundle identifier | Enabled project capabilities |
| --- | --- | --- |
| zLoader | `com.zynthec.zLoader` | App Groups, Network Extensions |
| zLoader Widget | `com.zynthec.zLoader.Widget` | App Groups |
| zLoader Tunnel | `com.zynthec.zLoader.Tunnel` | Network Extensions |
| zLoader Backup | `com.zynthec.zLoader.Backup` | App Groups |

The shared App Group is `group.com.zynthec.zLoader`, with the portal description
`zLoader Shared Data`. Host, Widget and Backup are assigned to it. The tunnel
currently does not request an App Group entitlement. Apple's default disabled
In-App Purchase checkbox is not a requirement of zLoader.

These four existing App IDs and their capabilities were inspected in the Apple
Developer Portal on 2026-10-06; their descriptions and the canonical App Group
description were saved. No provisioning profiles or IPA were created. Old IDs
and the old suffixed App Group are awaiting final deletion confirmation. Devices
and certificates are to be retained.

## Creating profiles manually

Create one iOS development provisioning profile for each of the four explicit
App IDs. Select the intended development certificate and target device for all
four. Host and Tunnel profiles must authorize
`com.apple.developer.networking.networkextension = [packet-tunnel-provider]`;
Host, Widget and Backup profiles must authorize the canonical App Group.
Enabling a portal capability alone does not verify the contents of the issued
profile. Inspect the downloaded profiles before signing.

## Signed Release artifact, 2026-10-06

After the portal naming stage, the user requested a signed IPA. Xcode automatic
signing issued profiles for the canonical four IDs using the existing local
Apple Development identity. No certificate or device was deleted.

`outputs/zLoader-0.7.14-Release-signed.ipa` contains the host, Widget and Tunnel
extensions and the separately signed embedded Backup IPA. The completed IPA's
four profiles were checked against the current portal device list: all seven
iPhones and the one iPad are authorized by every profile. Host and Tunnel
authorize `packet-tunnel-provider`; Host, Widget and Backup authorize the
canonical App Group. Profiles expire on 2027-10-06.

The Release build completed with zero reported warnings/errors. Apple-anchored
signature integrity, profile/certificate compatibility and nested IPA integrity
passed. The sibling JSON receipt contains results without device UDIDs or
private keys. Physical installation, launch and in-app refresh of this specific
artifact have not been tested.

Apple's team prefix in the signed `application-identifier` entitlement is
required and is distinct from appending a team suffix to `CFBundleIdentifier`.
The latter is not part of the canonical project identity.

## Local signing and existing installations

The ignored `CodeSigning.xcconfig` uses the canonical host ID and App Group.
The previous local identity is backed up under `.build/ReleaseCleanup`.
Installing this clean identity creates a different data container from an
existing suffixed/debug installation; no device installation or data migration
was performed as part of the portal setup.

Recovery and Apple-signed packaging scripts now use `Release-iphoneos`.
Certificate/private-key availability, issued profile contents, installation and
physical-device refresh remain separate verification steps. A signer that
rewrites identifiers or drops extension entitlements cannot preserve this setup
merely by using the same Apple account.
