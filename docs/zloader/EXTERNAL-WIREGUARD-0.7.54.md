# External WireGuard local tunnel — 0.7.54

The own Network Extension target, entitlements, provider source, self-provisioning
onboarding, recovery payload and package variants were removed. Apple signing of
other apps that contain network extensions still validates their own profiles.

The packet-loopback design is also used by the linked
[StosVPN provider](https://github.com/SideStore/StosVPN/blob/main/TunnelProv/PacketTunnelProvider.swift).
It rewrites IPv4 source/destination addresses and reinjects packets. In this build,
[EMProxy v0.9.3](https://github.com/SideStore/em_proxy/blob/v0.9.3/src/lib.rs)
accepts WireGuard UDP, decrypts IPv4 packets, swaps their source/destination bytes,
then encrypts and returns them to the external WireGuard client. A configuration
file alone is insufficient: zLoader starts this receiver before device operations.
StosVPN's NEPacketTunnelProvider itself is not embedded or copied into zLoader.

Onboarding and Connection Settings offer **Use WireGuard** and **Export WireGuard
Configuration**. The first export downloads the public loopback configuration
from the pinned SideStore/em_proxy v0.9.3 dependency and validates its address,
endpoint and key format. Later exports use a validated application-local cache.
No key is committed in this repository. Export routes only 10.7.0.1/32, keeps
DNS untouched and binds EMProxy to 127.0.0.1:51820. Import the `.conf` file in the
external WireGuard app, enable that tunnel and return to zLoader. This app starts
its local peer on becoming active and before device operations when WireGuard
is selected. Other external local VPN apps work with the toggle off.

WireGuard owns the VPN profile; zLoader does not programmatically enable or
disable that other app's VPN. Killing/suspending zLoader can interrupt its local
peer. On iOS 26.4+ the dependency rejects legacy Lockdown pairing over a non-IPSec
tunnel; use the on-device remote-protocol Self-Pairing flow. A missing tunnel is
shown as a red status dot and “Local Tunnel Missing”; pairing errors remain
separate readiness failures.

Validation: loopback configuration normalization/rejection/cache tests, transport
leases, App Groups, Core Data context confinement, expiry selection, actual UIKit
launcher data source in Simulator, project/settings checks, packet-tunnel signing
rules for third-party apps, Release build and IPA packaging.

Physical acceptance remains required: export/import the configuration on iPhone,
activate WireGuard, complete Self-Pairing, install and refresh an app; repeat on
cellular only, returning from WireGuard and after iOS background suspension. Build
and package checks do not establish those device-runtime results.
