# zLoader 0.7.17: on-device setup and optional internal tunnel

This version removes Xcode hosts, SSH credentials/project bindings, and the
EMProxy/WireGuard controls and startup paths from the app. The Xcode project
remains the source-build tool, not a runtime requirement for users.

## First installation

Use `zLoader-0.7.17-resignable.ipa` with a compatible installer. This bootstrap
variant installs the host and widget, with App Groups provisioned by the installer.
It does not install a Network Extension or request that entitlement on the host.
Its provider is included as inert ZIP data plus a SHA-256/version/build manifest;
it cannot run from that archive. The installer must retain ordinary app resources,
the widget, and the matching shared App Group. A fully unsigned IPA is a separate
artifact and may not expose capability metadata to every installer.

After Welcome, onboarding checks for LocalDevVPN, links to its App Store entry,
provides its activation/return URL, and checks actual peer reachability. Pairing
and Apple-account authentication follow. The selected team's membership determines
whether the optional internal-tunnel screen appears. Free accounts skip it.
A paid membership makes it offerable; Apple must still authorize the capabilities.
Nothing is signed until the user chooses **Internen Tunnel einrichten**.
**Nein, danke** continues with LocalDevVPN.

## Optional self-provisioning

1. Require the same eligible paid team as the installed zLoader app.
2. Preserve the installed host bundle ID and authorized App Group. Do not append
   another team suffix or silently migrate the data container.
3. In a temporary app copy, verify and unpack the bundled provider. Preserve all
   zLoader extensions and require their own profiles.
4. Discover/register App IDs, enable supported required capabilities, associate
   required App Groups, and reuse only profiles compatible with the actual private
   key/certificate, team, device, identity, expiration and requested entitlements.
5. Request missing profiles from Apple for that certificate and device. Reject any
   returned profile that omits required rights; never strip rights to claim success.
6. Sign host and extensions and install the replacement through the existing
   on-device pipeline while LocalDevVPN provides device access.
7. A pending state survives self-replacement. Reopen zLoader: it verifies the
   installed host/provider profiles **and signed entitlement requests**, asks for
   iOS VPN configuration consent, and tests a live UDID request through the tunnel.
   The green check requires that device-service request to succeed.

Signing may terminate the app when iOS replaces it; zLoader cannot guarantee an
automatic relaunch. LocalDevVPN remains selected until the replacement is verified.
A reset onboarding checks an already authorized tunnel rather than requiring the
external app again. Merely resetting onboarding does not re-provision the app.
A full `-internal-resignable.ipa` is also built for installers capable of provisioning
the provider initially. It is not the default bootstrap IPA.

Source updates from the fixed `https://altsource.zynthec.com` entry preserve the
installed identity. A bootstrap update restores the provider before provisioning
when the running installation already contains it; otherwise updates stay external.
Each executable extension has a separate profile. The embedded Backup IPA is not
an installed extension: its activation path separately provisions/signs it when used.

## VPN ownership and Shortcuts

External transport uses LocalDevVPN. Optional named before/after Shortcuts hooks
can connect/disconnect it around an install/refresh group and receive succeeded,
failed or cancelled outcomes. Hooks open Shortcuts, wait for nonce-bound callbacks,
require foreground use, and cannot guarantee cleanup after process termination.
Empty hook names leave switching manual. zLoader cannot directly stop another
app's VPN or discover/restore an arbitrary previous VPN. Hooks are skipped for
internal transport. No TurnOnData/TurnOffData or fixed operation-duration timer.

The internal provider uses operation leases shared by concurrent users. The final
release tears down a tunnel started by zLoader, including failure/cancellation.
It routes only the private virtual device destination, not the default Internet
route. Switching connection settings during an active operation may interrupt it.
Cellular-only device traffic still needs physical-iPhone verification.

## Local pairing

The bottom **Pairing starten** button now starts the server first,
keeps its transport lease, begins bounded iOS background execution, then opens
Settings only after the server-ready event. It attempts the undocumented route
`App-prefs:root=Privacy&path=DEVELOPER_MODE`, without opening zLoader's app-specific
Settings page as a fallback. This route is experimental and has not been verified
on iOS 27.0.1. iOS accepting the URL does not prove it honored the path; if it opens
only Privacy & Security, select Developer Mode manually. A rejected URL leaves the
server running and displays the manual navigation instructions.

The six-digit PIN updates the Live Activity and an immediate local notification
when notification permission is granted. After remote pairing the file is imported
directly into zLoader, then Lockdown pairing is attempted separately. Lockdown
failure preserves the valid remote file and offers retry/import. The Lockdown target
now uses the discovered/configured local peer rather than a hard-coded address.
A final notification and Live Activity let the user tap back into zLoader; the app
cannot force itself foreground while Settings is active. iOS can expire background
execution: the session is stopped and must be restarted. Live Activities do not
provide unlimited server execution. Denied notification permission/hidden previews
can prevent the PIN banner; the in-app PIN and permitted Live Activity remain.

## Validation and limits

Local transport, App Group, operation context, packet-tunnel profile, embedded-profile,
managed-signing, pairing import, and provider-integrity tests are available in
`zLoader/scripts`. Xcode Release compilation and IPA ZIP/signature structure are
separate from live Apple provisioning and physical-device installation.

Required acceptance tests remain: free/paid onboarding choices, live creation of
capabilities and matching profiles for a fresh certificate, successful self-replacement
from iLoader/SideStore, consent and tunnel reachability after reopening, Wi-Fi-off
refresh/install, PIN visibility in Settings, paired-device passcode/trust prompts,
and both saved pairing records. No physical success is claimed by local tests.
Original licenses/credits and the corresponding-source distribution requirement remain.

## Local verification on 2026-10-07

Final Release device build succeeded with no warning/error lines in its build log.
Transport, App Groups, context, provisioning/capability validation, profile reuse,
pairing import, storyboard/project configuration, managed signing and payload
integrity checks passed. Certificate export checks passed Apple Security,
independent OpenSSL and the pinned CodeSignKit importer; the standalone vendor
CodeSignKit test build still emits unused-variable warnings.
Both generated bootstrap and internal resignable IPAs passed ZIP, payload metadata,
extension layout, required-entitlement and ad-hoc signature structure checks.
These are local checks, not Apple-signed installation or physical pairing/cellular
acceptance. The Developer Mode URL path is explicitly experimental.
