# Validation and device acceptance

2026-10-05, local Apple Silicon macOS, Xcode 27.0 (27A266a), zLoader 0.7.1 (0701).

| Check | Result |
| --- | --- |
| Clean iOS arm64 Release build | PASS, zero warnings (`/tmp/zloader-final-clean-device.log`) |
| Final Release changes | PASS, zero warnings (`/tmp/zloader-final-device.log`) |
| Clean arm64 Simulator Debug build | PASS; one simulator-only unnecessary-try warning subsequently fixed |
| Final arm64 Simulator Debug build | PASS, zero warnings (`/tmp/zloader-final-simulator.log`) |
| App Group harness | PASS, 10 access/rename/ambiguity/prefix cases |
| Transport harness | PASS, overlapping leases, idempotent release, cancellation, failure recovery, serialized teardown/start |
| Core Data confinement harness | PASS, reads/writes, queued completion and propagated errors |
| Model identity audit | PASS, all 18 archived model versions preserve entity hashes and version identifiers |
| IPA packaging | PASS, ZIP integrity, nested signature seals and Mach-O XML entitlement slots read by SideSign |
| Embedded targets | zLoaderBackup, zLoaderWidget.appex, zLoaderTunnel.appex |
| Source/admin local tests | Feed tests, release pipeline tests, routing and mocked browser tests; see source project evidence |
| Hosted build CI | Not run; Actions disabled |
| UI Light/Dark / alternate icons on device | Not run |
| Apple login/provisioning and signed iPhone launch | Not tested |
| Cellular-only installation / refresh | Not tested on hardware |
| Intel Simulator | Original EMProxy/Idevice linking limitation; only arm64 validated |

The warnings fixes use Core Data queue confinement, MainActor UI ownership,
protected dependency callback state and modern API branches with iOS 15/16
fallbacks. No compiler warning category is disabled. Swift asset-symbol generation
is disabled because its generated Color.primary conflicts with the project's own
symbol; the asset itself remains present. The Minimuxer patch is tracked separately
with unchanged gitlinks and must be applied before direct Xcode builds.

The compiled model audit establishes schema equivalence, not physical-device data
migration. Existing database/metadata filenames are recognized. Bundle-ID or
App-Group changes can still result in a different iOS data container.

## Earlier 0.7.1 artifacts

- Previous `outputs/zLoader-resignable.ipa`:
  SHA-256 `6ca6173ec2b32be512ac646e1a785577602122737aa93d6af6ab2657b062e50f`.
- `outputs/zLoader-0.7.1.ipa` / `zLoader-unsigned.ipa` (requested release format):
  SHA-256 `d95402e528f64989b81d4b771238e62fe11932593f53dff39d7d1aa2faafe0fe`.

The resignable artifact uses local ad-hoc signatures to preserve capability
requests for SideStore import. It is not Apple-authorized or directly installable.
The unsigned artifact is for inspection. Neither proves the reported App Group
startup error has been resolved on the iPhone.

## Required device acceptance

1. Import with extensions retained; inspect final host/widget App Groups and
   host/provider Network Extension entitlements and their matching profiles.
2. Launch, complete onboarding and verify shared database/widget access without
   deleting the existing installation. Confirm the fixed source and self-update.
3. Accept/refuse VPN consent, check missing-capability errors, then exercise
   Wi-Fi+Cellular and Cellular-only login, signing, provisioning, transfer, install
   and single/batch refresh. Verify installed apps actually launch.
4. Overlapping operations, cancellation, VPN loss, failure and recovery must retain
   the tunnel until the last operation finishes.
5. Self-refresh, host suspension/termination and extension replacement need device
   validation. An OS-killed process can require manual VPN shutdown.
6. Test CoreDevice/RemotePairing and legacy lockdown separately. The embedded
   packet tunnel does not supply the IKEv2 interface required by upstream lockdown
   checks on iOS 26.4+. Unsupported combinations must fail clearly.
7. Light/Dark, Dynamic Type, VoiceOver, Reduce Transparency, alternate icons and
   About license/link rendering still require runtime review.

See [TRANSPORT.md](TRANSPORT.md) and [APP-GROUPS.md](APP-GROUPS.md).

User-selected distribution format is the fully unsigned IPA. This format lacks
Mach-O signing entitlements; SideStore import may omit App Group provisioning and
reproduce the reported container error. This limitation remains explicit.

## iLoader package follow-up

Latest installer is iLoader. Release build and all three local harnesses passed
again; `/tmp/zloader-iloader-build.log` has zero warnings/errors.
`outputs/zLoader-iLoader.ipa` contains host/widget App Groups and host/provider
Network Extension declarations with checked XML Mach-O slots and nested seals.
It matches the resignable artifact hash above. The signed-result checker correctly
rejects this ad-hoc artifact at the Apple-anchor check. A positive check against
a real iLoader-signed IPA has not been possible; no profile/account was supplied.
See [ILOADER.md](ILOADER.md) for verified upstream signer limitations.

## Settings and onboarding follow-up: 0.7.2 (0702)

- Final iOS arm64 Release build: PASS, zero warnings/errors,
  `/tmp/zloader-settings-pairing-device.log`.
- Final arm64 Simulator Debug build: PASS, zero warnings/errors,
  `/tmp/zloader-settings-pairing-simulator.log`.
- Apple-signing validator negative test: correctly rejects the ad-hoc package
  at the Apple-anchor check. A real iLoader-signed IPA is still unavailable.
- Settings storyboard regression: PASS for iOS and tvOS resource IDs, outlets,
  selectors and module. Six dangling destinations were removed in each resource.
- App Group (10 cases), Core Data confinement and all four transport test groups:
  PASS again.
- Packaging: PASS ZIP integrity, nested ad-hoc seals and entitlement/XML-slot
  checks; version/build inspected as 0.7.2/0702.
- `outputs/zLoader-0.7.2-iLoader.ipa` SHA-256:
  `9f2c5613e1502545318232e43a7ff130156be1e59a3258b0229194fcd541c87b`.
- `outputs/zLoader-0.7.2-unsigned.ipa` SHA-256:
  `b1bfb2e3744c9bd2ec291f34e594860f441d501d266313237bdfb19647a95be4`.

The iLoader package contains local ad-hoc metadata for re-signing; it is not a
real Apple-signed IPA. No simulator was booted, no runtime UI session was run,
and no iOS 27.0.1 crash report or physical-device pairing was available. See
[ONBOARDING-PAIRING.md](ONBOARDING-PAIRING.md) for implementation and device checks.

## Settings header initialization follow-up: 0.7.3 (0703)

The user supplied a physical-device Xcode screenshot identifying a nil measurement
prototype at SettingsViewController.heightForHeaderInSection. See
[ONBOARDING-PAIRING.md](ONBOARDING-PAIRING.md) for the initialization-order fix.

- Final iOS arm64 Release build: PASS, zero warnings/errors,
  `/tmp/zloader-settings-header-device.log`.
- Final arm64 Simulator Debug build: PASS, zero warnings/errors,
  `/tmp/zloader-settings-header-simulator.log`.
- Settings XML regression and all three local harnesses: PASS again.
- IPA packaging: PASS ZIP integrity, nested ad-hoc seals, capability/XML slots;
  version/build inspected as 0.7.3/0703.
- `outputs/zLoader-0.7.3-iLoader.ipa` SHA-256:
  `d857a703fee34913dc5c0b88eca3ddf5b22bf95845a5882f3cce6df4e8f82de6`.
- `outputs/zLoader-0.7.3-unsigned.ipa` SHA-256:
  `4e10be36147953a1f8ca5fe8fae3d2608067ff3eceeecb86b2301eb8dfebe8c0`.

No booted simulator was available and no updated physical-device Settings run
was performed here. Apple signing and on-device pairing limits remain unchanged.

## Xcode/self-refresh profile follow-up: 0.7.4 (0704), 2026-10-06

- iOS arm64 Release build: PASS, zero warnings/errors,
  `/tmp/zloader-tunnel-provisioning-device.log`.
- arm64 Simulator Debug build: PASS, zero warnings/errors,
  `/tmp/zloader-tunnel-provisioning-simulator.log`.
- New packet-tunnel request/authorization harness: PASS host/provider detection,
  widget exclusion, stale metadata repair, unrelated values preserved, idempotency
  and rejection of missing, wrong or malformed Apple authorization responses.
- Existing Settings XML, App Group, context and transport harnesses: PASS again.
- Packaging: PASS version/build 0.7.4/0704, ZIP integrity, nested ad-hoc seals and
  capability/XML entitlement-slot checks.
- `outputs/zLoader-0.7.4-iLoader.ipa` SHA-256:
  `6f78ddb691abfee25fb8cf9ce72823fafd9c033f7061fd3374e14c8516e50188`.
- `outputs/zLoader-0.7.4-unsigned.ipa` SHA-256:
  `ad5bd1c6818bd82440e612fde19d89b286ddb3ab1ee6939df2fd09036b7e6707`.

Existing local Xcode Debug host/provider signatures and profiles were inspected
read-only and authorize packet-tunnel-provider. This does not validate the
separate profiles downloaded during zLoader self-signing. No live Developer
Portal update or physical self-refresh test was performed. See
[SELF-REFRESH-SIGNING.md](SELF-REFRESH-SIGNING.md).

## Private signed release and profile reuse: 0.7.5 (0705), 2026-10-06

See [APPLE-SIGNED.md](APPLE-SIGNED.md) for outputs, hashes, signing/re-signing
validation and limits. Release default-ID build
(`/tmp/zloader-signed-profiles-device.log`), Xcode-ID Release build
(`.build/apple-signed-build.log`) and arm64 Simulator Debug build
(`/tmp/zloader-signed-profiles-simulator.log`): PASS, zero warnings/errors.
All existing local harnesses plus embedded-profile reuse checks pass. Signed
packaging and a second real Apple signing with the same identity preserve every
embedded profile and all declared entitlement values. Signing test logs:
`/tmp/zloader-apple-signed-package.log`, `/tmp/zloader-apple-resign-check.log`.
This is local signing/re-signing evidence, not an in-app physical self-refresh.

## Complete resignable follow-up (0.7.5)

The profile-inclusive resignable variant preserves every signed entitlement and
original Apple profile for host, Widget, Tunnel and embedded Backup. Nested seals,
ZIP integrity and exact XML entitlement-slot import checks pass. Artifact/hash and
re-signing limits: [APPLE-SIGNED.md](APPLE-SIGNED.md). No app source changed, so no
new Xcode compilation was required for this packaging-only change.

## Pairing host branding: 0.7.6 (0706), 2026-10-06

Client and server pairing now explicitly use the zLoader host name instead of
Minimuxer's SideStore default. See [ONBOARDING-PAIRING.md](ONBOARDING-PAIRING.md).

- Standard arm64 Release build: PASS, zero warnings/errors,
  `/tmp/zloader-pairing-brand-device.log`.
- Apple-signed Xcode-identity Release build: PASS, zero warnings/errors,
  `.build/apple-signed-build.log`.
- arm64 Simulator Debug build: PASS, zero warnings/errors,
  `/tmp/zloader-pairing-brand-simulator.log`.
- All existing local harnesses: PASS again.
- Complete Apple-signed and resignable packaging: PASS all extensions, Backup,
  profile preservation, entitlement comparison, XML import slots and ZIP integrity.
- Resignable IPA: `outputs/zLoader-0.7.6-resignable.ipa`, SHA-256
  `426e2030bfd09bde058698307f872856dc5989aee5625f41c06f030b5e22e55a`.
- Apple-signed IPA: `outputs/zLoader-0.7.6-Apple-signed.ipa`, SHA-256
  `a52e3b36cf158e1a329179ab35ad7eed0c23c7a970f8d699910b22df2386fd72`.

New visible pairing name on the physical target, installation and self-refresh
remain unverified here. Existing pairing records are retained.
