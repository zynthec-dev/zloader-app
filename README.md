# zLoader

Maintained by [zynthec-dev](https://github.com/zynthec-dev) in
[zloader-app](https://github.com/zynthec-dev/zloader-app).
**Based on [SideStore](https://github.com/SideStore/SideStore)**, nightly `0dd743f7`.
This is an independently maintained SideStore fork with its own development and releases.
It is not endorsed by the SideStore team; the corresponding source is available in this repository.

zLoader installs and refreshes apps on-device using an external local VPN tunnel.
Onboarding and Connection Settings can export a WireGuard configuration matching
EMProxy 0.9.3. Import it into the external WireGuard app and enable it before device
operations. zLoader runs the loopback peer at 127.0.0.1:51820 while its process is
running; the device route is 10.7.0.1/32. Configuration export needs internet once,
then uses a validated local cache. No internet routes or DNS settings are replaced.
The integrated Network Extension and its automatic provisioning/recovery flow
have been removed completely. Other compatible external local VPN apps remain
supported. Cellular-only and iOS suspension behavior need physical iPhone testing.

The fixed, non-removable default source is
[zLoader Source](https://zynthec.com/zloader/source.json). zLoader self-updates use its own
`com.zynthec.zLoader` entry; SideStore releases do not replace zLoader.

Self-updates hand the staged package to iOS's installation service before
terminating the old process. The first progress response, including 0%, is an
acknowledgement; waiting for positive progress can keep replacement stalled.
The installer uses the same IPA/directory choice as the AFC transfer. Release
0.7.46 fixes these paths, but a successful build does not establish device
replacement. Validate on an iPhone by refreshing/updating from an installed
0.7.46 or newer, reopening zLoader and checking the installed build and preserved
app records. An older build's broken updater needs an initial manual replacement
using the same app identity and App Group, without deleting the app.

## Build

Requires macOS, Xcode and the pinned submodules:

```sh
git submodule update --init --recursive
sh zLoader/scripts/apply-dependency-patches.sh
sh zLoader/scripts/test-transport.sh
sh zLoader/scripts/test-app-groups.sh
sh zLoader/scripts/test-context.sh
sh zLoader/scripts/test-packet-tunnel-provisioning.sh
sh zLoader/scripts/test-embedded-profile-reuse.sh
sh zLoader/scripts/test-pairing-import.sh
python3 zLoader/scripts/test-settings-storyboard.py
python3 zLoader/scripts/test-project-config.py
sh zLoader/scripts/test-certificate-export.sh
sh zLoader/scripts/test-codesignkit-export.sh
sh zLoader/scripts/test-managed-signing.sh
sh zLoader/scripts/test-portal-app-id.sh
sh zLoader/scripts/test-wireguard-config.sh
sh zLoader/scripts/test-lan-installer.sh
sh zLoader/scripts/build-unsigned.sh
python3 zLoader/scripts/test-bootstrap-package.py
```

Requires iOS 26.5+ to match the pinned binary dependencies.
For data-preserving Xcode installation, copy `CodeSigning.xcconfig.sample` to the
ignored `CodeSigning.xcconfig` and keep the installed host ID and App Group.
See [the audited Xcode setup](docs/zloader/PROJECT-AUDIT.md).

Open `zLoader.xcodeproj`, scheme `zLoader`. The dependency patch must also be
applied before a direct Xcode build. It is tracked separately, idempotent and
leaves the original dependency gitlinks intact.

The single sideloading release is `outputs/zLoader-resignable.ipa` (also aliased as
`zLoader-iLoader.ipa`). It contains the host, widget and App Group entitlement
metadata, with no embedded VPN provider or recovery payload. The external
WireGuard app owns the VPN extension and profile. `zLoader-unsigned.ipa` has the
same bundle layout with signatures removed. There is one sideloading release.
Read [on-device setup and limits](docs/zloader/ON-DEVICE-SETUP-0.7.17.md).
Profile-preserving inputs must not be fed to tools that append another team suffix.

- [Private Apple-signed IPA and preserving profiles](docs/zloader/APPLE-SIGNED.md)
- [Xcode installation and self-refresh profiles](docs/zloader/SELF-REFRESH-SIGNING.md)
- [Settings and onboarding wireless pairing](docs/zloader/ONBOARDING-PAIRING.md)
- [Pairing, key vault and P12 export changes in 0.7.13](docs/zloader/PAIRING-CERTIFICATES-0713.md)
- [Transport and iOS constraints](docs/zloader/TRANSPORT.md)
- [Build validation and device acceptance](docs/zloader/VALIDATION.md)
- [App Group startup and signing](docs/zloader/APP-GROUPS.md)
- [Provenance and own release source](docs/zloader/PROVENANCE.md)

License: [AGPL-3.0](LICENSE). Original copyrights and dependency licenses remain
in source and About, including SideStore, AltStore and LocalDevVPN/StosVPN credits.
Distribution must include access to the corresponding source. No entitlement
or signing bypass is provided.

Current validation and known gaps: [0.7.15 audit](docs/zloader/AUDIT-0.7.15.md).

Current setup: [LocalDevVPN bootstrap and optional managed tunnel, 0.7.17](docs/zloader/ON-DEVICE-SETUP-0.7.17.md).

Latest changes: [installation certificate recovery and Signed IPAs, 0.7.18](docs/zloader/CERTIFICATES-SIGNED-IPAS-0.7.18.md).

Appearance and connection corrections for 0.7.20: [validation and remaining device checks](docs/zloader/UI-TUNNEL-0.7.20.md).

Sources overview and local HTTPS IPA sharing in 0.7.28: [implementation and validation](docs/zloader/LAN-INSTALLER-0.7.28.md).
