# zLoader transport investigation and implementation

Baseline: SideStore/SideStore `nightly`, `0dd743f75afc358b0ba4a002feb5f19474492371`
(2026-09-20); inspected 2026-10-05. `develop` and `nightly` were identical on clone.
Pinned submodules remain unchanged: minimuxer `12be70dc`, SideSign `6b686516`.

## Findings

- `CellularRefreshManager` opened TurnOffData / TurnOnData, used a global Boolean,
  slept for configured delays and polled readiness for two seconds. URL-open
  success was not proof that a shortcut or device operation had finished.
- SendApp held data off until installation; refresh injected profiles; parallel
  refresh accumulated profiles for batch injection. Group and operation cleanup
  competed over the same global toggle. Batch injection lacked error cleanup.
- `ensureMinimuxerReady` skipped readiness entirely with cellular refresh enabled.
- Minimuxer selects localVPN or remoteServer. NetworkObserver discovers utun and
  a reachable peer. Lockdown uses AFC/installation proxy; RemotePairing/CoreDevice
  uses the IdeviceGateway/RemotePairingKit path. CoreDevice needs valid matching
  pairing material; it does not itself grant permission to configure iOS routes.
- StosVPN / LocalDevVPN use NEPacketTunnelProvider to reflect IPv4 packets, with
  interface 10.7.1.1/32 and peer 10.7.0.1/32. Only the peer route is included;
  default routing and DNS remain on the physical Internet connection.
- No public sandbox API was found to create the required local utun routing from
  an ordinary iOS app. A remote server is possible but does not meet same-device,
  no-external-app operation. NE is therefore embedded in this IPA.

## Implementation

`TransportLeaseCoordinator` shares startup and reference-counts UUID leases.
Last release requests teardown; new startup awaits prior teardown. Startup
failure and cancellation release waiters and clean up. No 10/30-second or other
transport-duration timer is used. NE status notifications determine connection
and disconnection. The full pipeline owns a lease across signing/provisioning,
AFC transfer, install/refresh and batch injection; direct device wrapper calls
acquire nested leases for standalone operations. Remote-server mode skips NE.
The tunnel starts only when a device operation needs it. User consent to adding
an iOS VPN configuration is mandatory and may require foreground interaction.
The manager discovers the actual embedded provider bundle ID after re-signing.
It stops only connections it started, not an already connected manual session.

Legacy shortcut preference keys / constants remain inert for existing preference
compatibility; executable calls and shortcut settings are removed. Cellular
refresh defaults to enabled, skips the Wi-Fi prerequisite only, and preserves
real endpoint/pairing readiness checks. The pre-existing 0.5-second self-reinstall
UI suspension delay is unrelated to tunnel duration and remains upstream code.

## Signing and runtime boundaries

Both host and extension need profiles authorizing
`com.apple.developer.networking.networkextension = [packet-tunnel-provider]`.
An entitlement file or unsigned build does not grant that capability. Free
Apple-account signing cannot supply it (also reflected in SideSign's entitlement
model). zLoader rejects automatic free-team tunnel provisioning and profiles
missing this entitlement before re-signing. Entitlements must never be stripped
to make this IPA appear successfully signed. App/extension IDs must match their
individual profiles and signed provider configuration. The extension consumes
an additional registered App ID; account quota and profile-expiration limits
remain Apple's constraints.

Cellular Internet staying enabled is implemented; working cellular-only
same-device installation is NOT established by compilation. Hardware must
validate route reflection, endpoint discovery and each protocol independently.
Minimuxer notes that lockdown on iOS 26.4+ requires an IKEv2/ipsec interface.
This packet tunnel does not fabricate that interface. Prefer legitimate matching
RemotePairing/CoreDevice configuration when available; otherwise report the
unsupported combination. No private cellular-switching API or entitlement
bypass was introduced.

App suspension, termination, self-replacement, extension replacement and iOS
background expiration can prevent host cleanup code from running. iOS owns
process lifetime; leases are not a guarantee of indefinite background execution.
An interrupted tunnel may need stopping in Settings. Status transition waits
are cancellation-aware, not a promise of device availability. Physical-device
coverage is mandatory before publishing claims of automatic cellular refresh.

## Sources

- https://github.com/SideStore/SideStore
- https://github.com/SideStore/minimuxer
- https://github.com/jkcoxson/LocalDevVPN
- https://github.com/SideStore/StosVPN
- https://developer.apple.com/documentation/networkextension/nepackettunnelprovider
- https://developer.apple.com/help/account/reference/supported-capabilities-ios/

LocalDevVPN/StosVPN design is credited; its complete license notices are bundled
in the app. SideStore's AGPL-3.0 license and original copyright notices remain.
