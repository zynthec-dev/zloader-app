# Appearance and source visibility — 0.7.27

Only the accent color remains configurable. Settings symbols follow that accent. Text fields retain native system text and background colors for Light/Dark appearance. Obsolete symbol/field overrides are removed on launch.

Programmatic Settings rows now use the same 22-point symbol size and leading positions as storyboard rows. This includes Signing Identities.

The inherited visible-app predicate excluded the store itself from every browse/source listing. That exclusion is removed; pledge-related visibility rules remain. zLoader can appear in All Apps and Featured Apps without changing the Source identity.

The requested LAN HTTPS IPA installation server is still absent. No server, certificate-trust flow, or target-device OTA installation is claimed implemented or tested in this release.

Required device check: Appearance controls, Signing Identities alignment with larger text sizes, and zLoader visibility after refreshing the Source. Build/archive validation is separate from this acceptance test.
