# Xcode installation and self-refresh profiles (0.7.4)

The reported error is a self-signing failure, not an Xcode installation failure.
On 2026-10-06 the available local Xcode Debug product was inspected read-only:
both host and provider signatures and their embedded provisioning profiles
contain `packet-tunnel-provider`; host has App Groups. No account credentials,
profile/device identifiers or signing assets are included in this document.
This comparison concerns the local build, not a remotely extracted iPhone binary.

zLoader requests profiles through its authenticated Developer Portal session.
Installing with Xcode does not mean its exact profiles or signing certificate
are reused by this operation. The error screenshot establishes that the returned
host profile lacks Network Extension authorization.

## Corrected requests

- Detect a packet-tunnel extension structurally in the host and provider.
- Request the Network Extensions capability even when cached/custom entitlement
  metadata lacks it. Preserve other requested provider types and entitlements.
- Merge requested features into existing App ID features instead of replacing
  the entire feature map and potentially losing already enabled services.
- Validate the returned Apple profile before proceeding, and retain the final
  pre-signing check for host and provider. Never write a requested entitlement
  into a profile as if Apple had authorized it.

These changes fix locally reproduced request-policy gaps. Without the live
account/profile response it remains unverified whether stale metadata or feature
replacement caused this particular device failure, or whether the current portal
API returns an incomplete profile despite a correct request.

## Retry and remaining Apple constraints

Update/run 0.7.4 from Xcode without deleting the current installation. Confirm
that zLoader authenticates the same eligible paid development team as Xcode,
then retry zLoader's own refresh/sign operation.

If the returned profile still fails authorization, inspect the actual host and
provider App IDs in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
For the IDs shown in the reported error these are `com.zynthec.zLoader` and
`com.zynthec.zLoader.Tunnel`; use the actual IDs if customized/team-suffixed.
Network Extensions must be enabled, and development profiles must authorize
`packet-tunnel-provider`. The widget retains its separate App Group requirement.
Regenerate the matching profiles after capability changes. A manually downloaded
profile alone does not prove the profile returned by zLoader's API is identical.

A successful Xcode launch is separate from self-refresh success. Test the updated
operation on hardware, confirm host/widget/tunnel remain signed and launchable,
then test pairing and refresh after relaunch. No live-account self-refresh or
physical pairing was run by the agent.

Apple references:
- [Configuring network extensions](https://developer.apple.com/documentation/xcode/configuring-network-extensions/)
- [Network Extensions entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension)
