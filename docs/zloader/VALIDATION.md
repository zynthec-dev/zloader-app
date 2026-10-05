# Validation and acceptance boundaries

2026-10-05, Xcode 27.0 (27A266a), local macOS Apple Silicon.

| Check | Result |
| --- | --- |
| Pinned nightly source + submodules | Cloned and inspected |
| App Group resolver harness | PASS: 10 cases for access, signer renaming, ambiguity and prefix boundaries |
| Swift transport lease harness | PASS: overlapping leases, duplicate release, cancellation during startup, failure recovery, teardown/start serialization |
| iOS arm64 Debug build | PASS |
| iOS arm64 Release build | PASS, final source; bundle contents inspected |
| iOS Simulator arm64 Debug build | PASS, final source (ARCHS=arm64 ONLY_ACTIVE_ARCH=YES) |
| Intel x86_64 Simulator | Fails linking upstream EMProxy/Idevice symbols; no dependency source modified |
| Tunnel embedding | ZLoaderTunnel.appex included in host PlugIns |
| App identity and licenses | CFBundleName zLoader; com.zynthec.zLoader; all three license resources checked |
| UI runtime Light/Dark | Not run; no booted Simulator available. Palette and native glass availability checked in source |
| Icons | Three 1024px alternatives generated; Mint icon visually inspected |
| Signed device install | Not tested; no supplied team/profile/device |
| Cellular-only install / refresh | Not tested on hardware; cannot claim supported end-to-end behavior |
| Live Apple login / provisioning | Not tested |
| Hosted CI / public release | Not run / not published |

## Required device acceptance

Use legally provisioned host/extension profiles and record iOS version, pairing
protocol and account type. Test:

1. First VPN-consent acceptance, refusal and missing-entitlement errors.
2. Wi-Fi + Cellular enabled, then Cellular-only: Apple login/provisioning,
   download, signing, AFC transfer, installation, single and batch profile refresh.
3. Check actual installed app launch and profile expiry, not just UI success.
4. Parallel operations, failed provisioning, transfer failure, installation
   failure, VPN loss, user cancellation and subsequent recovery. Tunnel must stay
   up until the final active operation releases its lease.
5. Self-refresh, host suspension/termination and extension replacement: inspect
   VPN state and verify post-relaunch data restoration. An OS-killed process can
   leave a connection needing manual shutdown; no timer pretends otherwise.
6. CoreDevice/RemotePairing and legacy lockdown separately. On iOS 26.4+, the
   embedded packet tunnel is not the IKEv2 interface required by upstream's
   lockdown checks. Unsupported protocol combinations must fail explicitly.
7. Light/Dark, Dynamic Type, VoiceOver and Reduce Transparency. About must show
   working links and complete license texts; alternate icons must switch.

See TRANSPORT.md for architecture, entitlement constraints and primary sources.

Unsigned review artifact: `outputs/zLoader-unsigned.ipa`. ZIP integrity, host and
provider bundle IDs, embedded provider and bundled license files were verified.
SHA-256: `662a2f6b78386930670526db5b16793f06a917f641cf7f17a0094504780780a7`.
This package is not signed or installability-tested.

GitHub repository is private. On 2026-10-05, after explicit user approval,
the unchanged SideStore baseline was pushed to `develop` and the zLoader
implementation to `zloader-development`. Default branch: `develop`. GitHub
Actions is disabled to prevent inherited SideStore publishing workflows from
running against upstream destinations. No release or hosted CI run was created.

Final verification also covers the tunnel-start status race fix: the initial
disconnected state is not treated as a completed failed connection attempt.
Both final Release device and arm64 Debug Simulator builds passed.

## App Group startup repair

Both device Release and arm64 Simulator Debug builds passed after the resolver
change. The resolver harness (10 cases) and transport harness (4 groups) passed.
`outputs/zLoader-resignable.ipa` preserves capability requests through local
ad-hoc signatures. Nested-code seal verification, ZIP integrity and the exact
Mach-O XML entitlement slot used by SideSign passed for host, widget and tunnel.
SHA-256: `aa4aae9b71e0f052f0ec46f721b07f106d9a0d04d7bfd33c2341c06ed1b91e5a`.
This is not an Apple-authorized installation signature. Final signed profiles,
device launch and resolution of the reported startup error remain unverified.
See APP-GROUPS.md for the confirmed packaging issue and re-signing steps.
