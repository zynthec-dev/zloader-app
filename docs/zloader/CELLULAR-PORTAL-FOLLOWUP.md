# Cellular transport and portal multi-selection follow-up

## Internal tunnel routing

The reflected device peer was also used as `tunnelRemoteAddress`. Apple documents
that the VPN server address is automatically excluded from tunnel routing. The
provider now uses loopback as the server placeholder (there is no remote server)
and includes only the private device peer /32. The excluded default route was
removed: no default route is included, so Internet signing traffic remains on the
physical connection. This removes conflicting routing declarations; it does not
prove that iOS exposes the required device services while Wi-Fi is off.

A connected saved tunnel now restores its peer into the host connection settings
rather than returning before doing so. Missing or invalid saved peers produce a
configuration error. Operation leases still own startup and final teardown; no
cellular toggling or operation-duration timers were added.

References:
- https://developer.apple.com/documentation/networkextension/neipv4settings/excludedroutes
- https://developer.apple.com/documentation/networkextension/neipv4settings/includedroutes

## Portal selection

Select is available for App IDs, App Groups, provisioning profiles, registered
devices and certificates. The selection screen supports Select All / Deselect All,
a destructive confirmation, serial remote changes and per-item failure reporting.
Certificates use Revoke Selected. Entries are removed locally only after the
existing portal mutation and a fresh server-side list confirm removal. Resource
changes prune stale selections, and each mutation resets its previous error.
Apple may reject deletion of resources with dependencies; such failures are kept.

No real Apple-account resources were deleted to validate this implementation.
This is not a claim of complete Developer Portal resource parity.

## Validation

Transport lease, App Group, context confinement, managed signing, embedded-profile
reuse, packet-tunnel provisioning, pairing import, project configuration and
Settings storyboard checks passed. Release build and IPA packaging results are
recorded in `.build/zloader-cellular-portal-build.log`.

Required device acceptance: integrated tunnel on, Wi-Fi off, cellular Internet on;
refresh a regular app and zLoader, confirm actual installation, then confirm tunnel
teardown. Also test Wi-Fi and an already-connected saved tunnel after relaunch.
A failed device-service TCP probe must remain an error, never a synthetic success.
