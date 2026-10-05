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

## Artifacts

- `outputs/zLoader-resignable.ipa`:
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
