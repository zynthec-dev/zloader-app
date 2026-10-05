# Validation and acceptance boundaries

2026-10-05, Xcode 27.0 (27A266a), local macOS Apple Silicon.

| Check | Result |
| --- | --- |
| Pinned nightly source + submodules | Cloned and inspected |
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
SHA-256: `2a22b246645f26299c4bf9395ab451e60d2ccbfdb91bc5b411fdd599c1b1697a`.
This package is not signed or installability-tested.

GitHub repository was created private. Source push and remote Actions/default
branch configuration await explicit approval after automatic review rejected
that export. All current implementation is available in the local branch.
