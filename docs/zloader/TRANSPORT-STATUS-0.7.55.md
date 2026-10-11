# Transport status correction — 0.7.55

The launcher previously treated every readiness failure except selected pairing
errors as “Local Tunnel Missing”. This included a Wi-Fi-only readiness result
published by the dependency when a local tunnel operated over cellular, an
uninitialized device service, missing pairing, and incompatible Lockdown pairing.

The launcher now rechecks network-path failures through the app's local-service
readiness check without a Wi-Fi requirement. Status distinguishes a missing
interface/peer, an unreachable device endpoint, required/failed/incompatible
pairing, startup and other device-service failures. A connected tunnel is not
reported as absent merely because another readiness condition fails. Labels
are translated in English and German; existing layout and colors are retained.

WireGuard's VPN profile can remain “active” while zLoader's loopback receiver is
suspended. The receiver runs inside zLoader, not WireGuard's Network Extension.
Switching to another app such as StikDebug therefore does not provide a reliable
persistent device tunnel. Use an independent compatible local VPN app for that
workflow. This correction does not promise unrestricted background execution.

Checks: transport-status regression cases, transport lease/App Group/context
checks, WireGuard configuration validation, project/settings checks and Release
build/package validation. Device acceptance: return from WireGuard, inspect the
status on Wi-Fi and cellular, repeat with missing/incompatible pairing and with
VPN disabled. No physical-device acceptance result was obtained in this run.
