# Validation and device acceptance

## Current project audit — 0.7.12 (0712), 2026-10-06

- Full clean arm64 iOS Release: PASS, zero warnings/errors,
  `/tmp/zloader-audit-clean-release.log`; unsigned and capability-metadata
  installer packages generated and ZIP-checked.
- Full arm64 iOS Simulator Debug build: PASS, zero warnings/errors,
  `/tmp/zloader-audit-clean-simulator.log`; no simulator UI or physical device
  acceptance was performed.
- All eight README test scripts: PASS (transport, App Groups, Core Data context,
  provisioning, embedded profile reuse, pairing imports, Settings storyboards,
  cross-target project configuration).
- Expanded Apple-signed IPA validation: PASS on existing private
  `zLoader-0.7.11-Apple-recovery.ipa`, including nested Backup, exact child IDs,
  shared group, certificate/profile authorization and same team. This is not a
  new 0.7.12 signed build or a portal revocation check.
- Apple-signed Debug build: BLOCKED, `/tmp/zloader-audit-signed-final.log`: Xcode
  reports No Accounts and no development certificate/private key. macOS reports
  zero signing identities. No 0.7.12 device install was performed.
- Deployment minimum is now iOS 26.5 to match the actual pinned binary
  dependencies. Rebuilding dependencies is necessary for older iOS support.
- Direct source endpoint request: HTTP 403; live feed verification unavailable
  from this audit client, with no server changes.

Local 0.7.12 artifact SHA-256 values:

- `outputs/zLoader-unsigned.ipa`: `6228d2caa83fca06e8e0d67175f5e25a254872a6d41c8eaef5dace6183dbc19e`.
- `outputs/zLoader-0.7.12-resignable.ipa`: `adebe0f218c2b140e2feb072fc16c7c5e4793c6857d6436b11f64140fa7f376e`.

The audit removed inherited linker `-w`; earlier zero-warning logs did **not**
show all linker diagnostics. The exposed dependency deployment mismatches and
subsequent API deprecations were corrected, rather than suppressed. Older
results below remain historical and are not evidence for current device behavior.

See [PROJECT-AUDIT.md](PROJECT-AUDIT.md) for installation steps and hardware
acceptance limits.

## Historical evidence

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


## 0.7.7 (2026-10-06)

- All six local validations passed: transport, App Groups, context, tunnel
  provisioning, profile reuse and Settings storyboard checks. Profile reuse
  coverage also verifies extension identifiers for preserved and migrated hosts
  and rejects parent-prefix collisions.
- Final unsigned Release/device build and the Apple-signed packaging device build
  passed with zero warning/error diagnostics. No warning categories were disabled.
- Apple signature/profile verification passed for host, widget, tunnel and nested
  backup. Full resignable packaging preserved every original profile and XML
  entitlement slot; it still requires actual Apple signing before installation.
- The Apple-signed 0.7.7 build was installed and launched through CoreDevice on
  the user's connected iPhone running iOS 27.0.1. A subsequent process query found
  the app running. This proves initial launch, not Settings interaction or VPN
  consent. No automatic Apple account authentication, certificate import or
  private-key export was performed.
- Actual VPN authorization/connection, pairing, account-backed self-refresh and
  cellular-only behavior remain pending device interaction and error feedback.
- Existing project.pbxproj and Info.plist user changes were preserved.

## 0.7.8 (2026-10-06)

- Existing six regression checks passed; new `test-pairing-import.sh` passed using
  the actual manager and Minimuxer parser with synthetic records. Covered combined
  iLoader data, binary plists, both protocol records, selected Lockdown, remote-only
  fallback and retention of invalid input. No real pairing credentials are fixtures.
- Profile reuse tests verify that rotating the key rejects the old profile and
  accepts a newly authorized profile for the new key. Live Apple profile issuance
  is not simulated as a success by these tests and still requires account testing.
- Final Apple packaging/device build passed with zero warning/error diagnostics;
  signed host, widget, tunnel and nested backup profile checks passed. Full
  resignable packaging preserves profiles and entitlements but remains ad-hoc
  metadata until an eligible signer signs it.
- iLoader and SideInstaller patches passed context/application checks. The actual
  patched SideInstaller matching code was compiled in an isolated harness and
  found zLoader with base, team-suffixed and custom IDs; existing SideStore matched.
  No upstream messages, submissions or external application installs were made.
- Pairing document registration and File Sharing flags were checked. StikPair
  share-sheet appearance, direct third-party placement, real trust authorization,
  device registration, cellular-only refresh and self-resign remain device/account
  acceptance checks, distinct from builds and signature checks.

- Apple-signed 0.7.8 was physically installed and launched via CoreDevice on the
  user's connected iPhone. This verifies initial launch, not the new live-account
  profile issuance or VPN/Share Sheet interaction.

## Installed-identity repair: 0.7.9 (0709), 2026-10-06

CoreDevice confirmed that the failing installation used a team-suffixed Debug
identity. The previous Apple-signed 0.7.8 IPA used the unsuffixed Debug identity,
so its successful signing/launch checks did not repair this installation.

- Xcode issued development profiles for the actual installed host, Tunnel,
  Widget and Backup IDs. The host and Tunnel profiles authorize
  `packet-tunnel-provider`; host/Widget retain the installed shared App Group.
- Apple recovery Debug build: PASS, zero warning/error diagnostics in
  `.build/apple-recovery-build.log`. A local Xcode Widget version override was
  corrected to inherit the host version after the first build reported a mismatch.
- Recovery package: PASS Apple-anchored seals, active profile/certificate
  authorization, exact requested bundle IDs and host/Widget group preservation,
  independently Apple-signed embedded Backup, and ZIP integrity.
- All seven local validation scripts: PASS, including distinct installed-profile
  failure cases. Generic LocalDevVPN recovery advice was removed.
- CoreDevice installation over the existing team-suffixed app and initial launch:
  PASS. No app deletion was performed. Data access, VPN consent/connection,
  actual pairing, live-account self-refresh and cellular-only operation have not
  been established by these checks.

Private artifact: `outputs/zLoader-0.7.9-Apple-recovery.ipa`.
SHA-256: `b4ad66f9788b765eb9c8269b6abe157986a7a46398fa05b11431c1fce44f9d4a`.
No signed IPA, profile, credentials or pairing data were published or committed.

- Final unsigned Release build and package: PASS, zero warnings/errors,
  `/tmp/zloader-079-unsigned.log`.
- Full 0.7.9 resignable import package regenerated from the verified recovery IPA:
  PASS original profile bytes and all entitlements preserved, XML entitlement slots
  checked. This derivative is ad-hoc metadata and needs proper Apple re-signing.
- Post-install CoreDevice inventory confirms 0.7.9/0709 under the same installed
  bundle ID and shared App Group. The user's pending VPN/refresh result remains
  the runtime acceptance criterion.

## Self-update identity and precise profile errors: 0.7.10 (0710)

The user's 0.7.9 screenshot reached newly issued profile validation and showed a
Release-derived ID instead of the running Debug identity. The old validation error
appended a packet-tunnel warning for every failed predicate, so that screenshot
alone did not establish which certificate/device/group/capability check failed.

- Own host identity now follows the running Apple-profile identity for the same
  team before stale database/downloaded Release identities. Extension IDs derive
  from this resolved host.
- Host/Widget App Groups are recovered from the running authorized profile before
  portal feature and group updates, including unsigned updates without entitlements.
- Validation reports actual failing fields without disclosing certificates or
  device IDs, and keeps every existing authorization predicate.
- All seven local scripts: PASS. Added same-team/different-team identity checks,
  and exact device/group error checks that reject misleading VPN attribution.
- Final Apple recovery build: PASS, zero warnings/errors. Host/Widget/Tunnel/Backup
  signatures, Apple profiles and requested installation identity/group checked.
- CoreDevice update installation and launch on the user's iPhone: PASS. The user confirmed successful
  in-app refresh on this device. No third-party installer roundtrip
  is claimed from the local Apple-signing check.

Private Apple-recovery IPA SHA-256:
`6443fe32a814072761a9ededb45c58e633d0e3927e4bfb49cedf6148db9395db`.

- User acceptance: "Refresh funktioniert" after the final 0.7.10 installation.
  Post-refresh CoreDevice inventory confirms the same installed app ID, shared
  App Group and version/build 0.7.10/0710. This is a successful device self-refresh
  report, distinct from testing every certificate, third-party installer or
  cellular-only transport. App data contents were not inspected.
- Final unsigned Release build/package: PASS, zero warnings/errors. Full import
  package: PASS all original profile bytes, complete entitlements and XML slots
  preserved; ad-hoc import metadata still requires proper Apple re-signing.

## iLoader double suffix and package separation: 0.7.11

The user identified iLoader with the previous resignable IPA as the latest
installer. The package preserved the already team-suffixed Xcode Debug identity;
the inspected isideload generic path appends the team ID unconditionally.
CoreDevice confirmed a host and shared group both ending in two copies of the
team ID. The user screenshot confirms the installed profile lacks packet-tunnel
permission. An IPA that preserves an already signed identity is therefore the
wrong input for this installer path.

- Generic/iLoader packages now always use the base host and child identities,
  without team-bound profiles. Versioned iLoader/resignable aliases are produced.
- Profile-preserving packages have distinct names/alias and cannot overwrite
  iLoader/generic import packages. Existing versioned older outputs are historical.
- zLoader's own fallback team suffix is idempotent; existing double-suffixed
  identities are deliberately not normalized into different containers.
- All seven validation scripts passed. Release build: PASS, zero warnings/errors.
  Generic IPA checks confirmed base host/Widget/Tunnel/Backup IDs, no embedded
  team profiles, retained extension capabilities and ZIP/signature metadata.
- Xcode Apple build for the canonical once-suffixed iLoader target IDs: PASS,
  zero warnings/errors; all target signatures/profiles and required capabilities
  verified. `zLoader-0.7.11-Apple-iloader-ID.ipa` is kept privately. This prepares
  these App IDs in the selected paid team; an actual iLoader re-sign/install still
  requires a separate check of the profiles/signatures it returns.

- Current double-suffixed installation repaired with exact existing host/extension
  IDs and App Group, rather than silently changing containers. Apple build and
  full profile/signature verification: PASS, zero warnings/errors. CoreDevice
  update installation and launch: PASS. No app deletion was performed; app data
  contents were not inspected. VPN consent and self-refresh after this iLoader
  repair need a new physical-device test; the earlier successful 0.7.10 refresh
  preceded the user's external iLoader re-sign/install.
- Profile-preserving package check: PASS all target entitlements/profile bytes
  retained and generic iLoader input SHA unchanged before/after packaging.
- Private current-identity repair IPA SHA-256:
  `3f062967a111a531173aea704b21d8bd0f6e82030b60340cb3bc191bf473269a`.
- zLoader-created signing certificates need not equal Xcode's certificate. The
  profile reuse/issuance policy checks the actual selected certificate DER and
  device/capabilities; same-team app identity/group preservation is independent
  of retaining Xcode's original private key. Arbitrary certificates cannot grant
  capabilities absent from Apple's profiles.


## 0.7.13 (0713), 2026-10-06

See [pairing/certificate changes and remaining device limits](PAIRING-CERTIFICATES-0713.md).

- Eight existing validation scripts PASS; Apple/OpenSSL certificate export and
  pinned CodeSignKit import compatibility scripts PASS (ten total).
- Release iOS build PASS, zero warnings/errors (`/tmp/zloader-0713-device-final2.log`).
- arm64 Debug Simulator build PASS, zero warnings/errors (`/tmp/zloader-0713-simulator.log`).
- Separate native macOS SwiftPM compatibility harness PASS, with unsuppressed
  upstream BoringSSL integer-conversion warnings.
- Resignable IPA SHA256: `1a83985790901b409f3211bb1fd23efb8299967232f603a195bde4cb050376c8`.
- Unsigned IPA SHA256: `f62c438f1030cfecbba5b1abc243a30344239de785364ea0c03e69be1793fc36`.
- Embedded Widget/Tunnel retained; Backup packaging completed. Resignable
  means ad-hoc capability-bearing installer input, not an Apple-authorized IPA.
- No new Apple signing/install: Mac reports zero valid code-signing identities.
- Cellular-only endpoint/refresh, both native pairing exchanges, Keychain UI
  persistence, Feather import, Light Mode UI and Dynamic Island require device
  acceptance. Cellular is not reported as fixed from compilation alone.
- Unrelated user project settings and Info.plist display-name ordering preserved.


## 0.7.14 (0714), 2026-10-06: Light Mode follow-up

- 51 Settings storyboard text colors now use semantic labels; fixed white text
  was still present after 0.7.13 and is removed in this release. Headers/footers,
  separators and inset selection/background states adapt to appearance too.
- Settings Highlighted asset changed from inherited purple to pale/deep mint.
  Black/light and white/dark title contrast is 17.21:1 / 11.69:1 on these solid
  backgrounds. Blur compositing and secondary labels need visual inspection.
- App/source subtitle vibrancy and No Updates vibrancy are removed so semantic
  foregrounds render directly. The No Updates label no longer uses the same tint
  as its background. Filled legacy buttons use contrast-aware text.
- Eight existing validation scripts PASS; Settings selectors/outlets/resources
  and all target entitlements remain valid. Crypto/signing code is unchanged.
- Final unsigned Release device build PASS, zero warnings/errors:
  `/tmp/zloader-0714-device-final.log`.
- arm64 Simulator build PASS, zero warnings/errors; final resource check log:
  `/tmp/zloader-0714-simulator-final.log`.
- Actual Settings storyboard displayed by debugger root replacement in a fresh
  isolated iOS 27 simulator. Visible titles, static rows and footer text are
  readable in Light/Dark screenshots under `.build/ThemeReview`. A notification
  consent dialog overlays part of the screen, so this is partial visual coverage,
  not a full screen-by-screen device acceptance. No runtime root change is shipped.
- Resignable IPA SHA256:
  `91a9a40a0f3b5e780fe82e6cc18e75bdbebca43c6f5ca2a2d4c3a32efa09797b`.
- ZIP packaging and embedded extensions retained. No Apple signing or physical
  device test is claimed. Unrelated project/Info.plist edits remain unstaged.
