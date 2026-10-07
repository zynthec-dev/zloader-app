# zLoader 0.7.20: appearance and connection corrections

## Changes

- Signed IPAs is an English row below Background Refresh and Disable Idle Timeout in the Refreshing Apps card. Its switch uses the existing `isExportResignedAppEnabled` preference; tapping the title opens the saved-file library. The duplicate User Customizations control and library control were removed. Existing files remain accessible when saving is disabled.
- Authentication labels use semantic primary/secondary text rather than fixed white. Input cards and sign-in buttons use the shared palette and contrasting button text.
- Settings panels use semantic text. Mint backgrounds, card surfaces and highlighted elements are distinct in Light and Dark. UIKit tint and surface roles and SwiftUI hosting roots use the selected theme. App artwork keeps its own colors.
- LocalDevVPN readiness observes both discovered and configured peer probe updates. The local backend's actual configured peer is used for the readiness result. Rebinding the UI invalidates the previous network comparison so unchanged interfaces still publish fresh probe results. Internal custom peer addresses are no longer replaced by the default address.
- SideSign now sends the legacy Developer Services service identifiers for Network Extensions, Personal VPN and the other mapped legacy capabilities. Previously it sent human-readable names for these services, which could leave profiles unauthorized. Profile authorization remains mandatory: no entitlement is fabricated and Apple rejection remains an error.

Service identifiers were checked against Fastlane's primary source:
https://github.com/fastlane/fastlane/blob/master/spaceship/lib/spaceship/portal/app_service.rb

## Validation

Release device build and bootstrap IPA integrity checks passed. Local transport, App Group, managed-context, managed-signing, tunnel-provisioning, embedded-profile-reuse, pairing-import, tunnel-payload, storyboard and project configuration checks passed. Default accent contrast with the chosen button text is 5.08:1 in Light and 11.44:1 in Dark. These calculations do not replace visual inspection on a device.

## Device and Apple-account checks still required

This release has not proved live Apple issuance of a Network Extension profile, installation/refresh on hardware, internal VPN startup, cellular-only device-service reachability, or complete visual coverage of every screen. The external bootstrap package still requires LocalDevVPN for initial device access. Its embedded provider payload can only be installed by the optional self-provisioning flow if Apple's actual host and extension profiles authorize it.

Acceptance checks: enable LocalDevVPN while onboarding is open, return without restarting and verify the green state; verify light/dark authentication and cards; select another theme and navigate through tabs/settings; enable the optional internal tunnel with an eligible team, reopen after installation and verify real device-service access; refresh with Wi-Fi disabled; verify the Signed IPAs switch and existing-file library.
