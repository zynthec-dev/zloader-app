> Historical 0.7.16 design; superseded by [0.7.17 on-device setup](ON-DEVICE-SETUP-0.7.17.md).

# zLoader 0.7.16: external local VPN and Shortcuts

This supersedes the internal-tunnel transport described in the earlier audits.
The internal provider, Xcode target, embed dependency and host Network Extension
entitlement are removed. zLoader, Widget and nested Backup retain their App Group
requirements. Installers still must preserve/re-provision those groups and targets.
Changing VPN providers does not itself fix a failed Apple account login, pairing
record, profile, device authorization or app installation.

Onboarding and Connection Configuration offer the LocalDevVPN App Store link
when its declared URL scheme cannot be opened. When installed, Activate opens
`localdevvpn://enable?scheme=zloader`, requesting the documented return callback.
The callback is not proof of connection. A real local peer reachability check
controls Continue. LocalDevVPN owns its VPN configuration and system consent.
zLoader does not stop an external VPN or request NE configuration privileges.

## Shortcuts

The existing install and refresh App Intents remain available. Two additional
foreground actions, 'IPA installieren mit Ergebnis' and 'Alle Apps refreshen mit
Ergebnis', return Erfolgreich, Fehlgeschlagen or Abgebrochen after the pipeline finishes.
Routine failures return their status plus a diagnostic dialog instead of throwing, allowing a following cleanup
action to run. Install includes signing/provisioning; there is no standalone
sign-only IPA export action or custom system 'On Refresh' event trigger.

Build a shortcut on the iPhone:

1. Set VPN: connect the named LocalDevVPN configuration.
2. Run the desired zLoader outcome action, passing an IPA for installation.
3. Set VPN: disconnect LocalDevVPN.
4. Inspect the outcome and optionally reconnect your known personal VPN.

App-action discovery is supplied by zLoader's AppShortcutsProvider; no imported
shortcut is required to make these actions visible. VPN identity selection and
personal app-open/app-close automation are configured in Shortcuts on the device.
An app-close trigger also fires when leaving the app and may interrupt a running
install. Prefer the operation sequence over app-close automation. If the entire
shortcut is cancelled/killed or the device suspends it, cleanup is not guaranteed.

zLoader cannot reliably enumerate an arbitrary previously active third-party VPN
and restore it. A known named VPN can be reconnected explicitly by the user's
shortcut. Two packet-tunnel VPN apps such as Tailscale and LocalDevVPN should not
be expected to coexist. Apple supports certain Personal VPN + enterprise VPN
combinations; this is not general permission for two simultaneous packet tunnels.

## Validation boundary

The Release build, packaged IPA target/entitlement inspection, project layout and
local pipeline/transport tests validate implementation and artifact structure.
Actual LocalDevVPN handoff/return, system VPN consent, Shortcuts execution and
iPhone installation/refresh (including cellular-only) need physical-device checks.
A previous report of failed refresh still needs the actual error text to identify
its stage. No current success on physical hardware is asserted.

References:
- https://github.com/jkcoxson/LocalDevVPN/blob/main/LocalDevVPN/LocalDevVPNApp.swift
- https://support.apple.com/de-de/guide/shortcuts/apdfbdbd7123/ios
- https://developer.apple.com/documentation/networkextension/netunnelprovidermanager
- https://tailscale.com/docs/reference/faq/other-vpns

SSH hosts that are reachable only through Tailscale may become unreachable when
LocalDevVPN replaces Tailscale. Build/download the IPA while Tailscale is active,
then switch to LocalDevVPN to install, or use a host reachable on the local network.
Automatic linked-host refresh does not currently orchestrate this VPN handover.

## Hooks for actions initiated inside zLoader

Connection Configuration/Onboarding additionally accepts names of optional
Before and After shortcuts. Before runs prior to local transport initialization;
After runs once the entire operation group, including batch injection, has finished,
or after a failure/cancellation. JSON input contains `event` (before, succeeded,
failed, cancelled) and `bundleIdentifiers`. While hooks are enabled, simultaneous
groups are rejected so cleanup cannot disconnect a second group's transport.

zLoader invokes the configured user shortcut through Apple's x-callback-url
protocol and awaits a matching nonce callback, not a fixed delay. The hook must
finish and return; opening LocalDevVPN is not itself proof of readiness. Missing
callback can be cancelled from Connection Configuration. Cleanup is attempted
even for a cancelled operation and a failing startup hook, but cannot survive
process termination or run reliably while locked/backgrounded. Completion-hook
failures are logged and do not change an already completed install into a failure.
No custom system automation trigger, silent third-party VPN control, signed
shortcut download or automatic prior-VPN restoration is claimed.

The hook shortcut should contain the native Set VPN action and must not start
another zLoader install/refresh (recursive hooks would deadlock/reject). Hooks
are empty/disabled by default. Physical Shortcuts handoff/return remains untested.
