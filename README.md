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
[zLoader Source](https://source.zloader.de). zLoader self-updates use its own
`com.zynthec.zLoader` entry; SideStore releases do not replace zLoader.

Self-updates hand the staged package to iOS's installation service before
terminating the old process. The handoff occurs after the complete Install
command has been written and flushed. Waiting for an installation-progress
response can keep replacement stalled while iOS waits for the old process to exit.
The installer uses the same IPA/directory choice as the AFC transfer. Release
0.7.46 fixes these paths, but a successful build does not establish device
replacement. Validate on an iPhone by refreshing/updating from an installed
0.7.46 or newer, reopening zLoader and checking the installed build and preserved
app records. An older build's broken updater needs an initial manual replacement
using the same app identity and App Group, without deleting the app.

The adjacent Container page embeds the pinned original LiveContainer runtime,
management views, multitasking and tweak support. IPA imports offer device or
container installation. General Container settings select the host's identity or
one shared virtual identity for all guests. See [container setup, provenance and
acceptance testing](docs/zloader/CONTAINERS.md). Device signing, JIT availability,
Apple permissions and physical-device lifecycle remain separate acceptance checks.
The [0.8.1 integration notes](docs/zloader/CONTAINER-081.md) describe automatic
signing identity selection, integrated JIT launching, window ownership and legacy
browser callbacks, including the remaining device validation.

## Build

Requires macOS, Xcode and the pinned submodules. The independent certificate-export
checks require OpenSSL 3 on PATH (including its valid openssl.cnf); the system
LibreSSL does not provide the same Unicode PKCS12 CLI behavior:

```sh
git submodule update --init --recursive
sh zLoader/scripts/apply-dependency-patches.sh
sh zLoader/scripts/test-transport.sh
sh zLoader/scripts/test-transport-status.sh
sh zLoader/scripts/test-app-groups.sh
sh zLoader/scripts/test-context.sh
sh zLoader/scripts/test-installation-presentation.sh
sh zLoader/scripts/test-app-launcher.sh
sh zLoader/scripts/test-containers.sh
sh zLoader/scripts/test-install-acknowledgement.sh
sh zLoader/scripts/test-packet-tunnel-provisioning.sh
sh zLoader/scripts/test-embedded-profile-reuse.sh
sh zLoader/scripts/test-pairing-import.sh
python3 zLoader/scripts/test-settings-storyboard.py
python3 zLoader/scripts/test-settings-style.py
python3 zLoader/scripts/test-project-config.py
sh zLoader/scripts/test-certificate-export.sh
sh zLoader/scripts/test-codesignkit-export.sh
sh zLoader/scripts/test-managed-signing.sh
sh zLoader/scripts/test-watch-signing.sh
sh zLoader/scripts/test-extensionkit-signing.sh
sh zLoader/scripts/test-apple-login.sh
sh zLoader/scripts/test-anisette-migration.sh
sh zLoader/scripts/test-anisette-protocol.sh
sh zLoader/scripts/test-certificate-revocation.sh
sh zLoader/scripts/test-portal-profile-resolver.sh
sh zLoader/scripts/test-account-certificate-policy.sh
sh zLoader/scripts/test-source-ipa-file.sh
sh zLoader/scripts/test-ipa-archive-metadata.sh
sh zLoader/scripts/test-safe-archives.sh
sh zLoader/scripts/test-portal-app-id.sh
sh zLoader/scripts/test-portal-capabilities.sh
sh zLoader/scripts/test-wireguard-config.sh
sh zLoader/scripts/test-lan-installer.sh
sh zLoader/scripts/build-unsigned.sh
python3 zLoader/scripts/test-bootstrap-package.py
```

The canonical build also rebuilds the pinned iDevice installer with the tracked
status-acknowledgement fix. Rust 1.99.1 is installed only inside the ignored
`.build/RustToolchain` directory when absent. Before direct simulator or tvOS
builds, resolve packages and run `prepare-patched-idevice.sh ios-simulator`,
`tvos`, or `tvos-simulator` for that destination. Serialize these builds.

Requires iOS 26.5+ to match the pinned binary dependencies.
For data-preserving Xcode installation, copy `CodeSigning.xcconfig.sample` to the
ignored `CodeSigning.xcconfig` and keep the installed host ID and App Group.
See [the audited Xcode setup](docs/zloader/PROJECT-AUDIT.md).

Open `zLoader.xcodeproj`, scheme `zLoader`. Resolve packages into
`.build/SourcePackages` first, then run `apply-dependency-patches.sh` before a
direct Xcode build. This also patches CodeSignKit's DER entitlement encoder;
`build-unsigned.sh` performs both steps automatically. SideSign changes are
consolidated in `sidesign-managed-signing.patch` so overlapping patches can be
applied repeatedly. It is tracked separately, idempotent and
leaves the original dependency gitlinks intact.

Watch companion IPAs are prepared as complete signing component graphs: the phone,
Watch app and nested extensions each receive their own profile and final identity.
See [Watch signing and refresh](docs/zloader/WATCH-SIGNING.md) for registered-device
requirements, the optional full Clawy fixture test and remaining hardware checks.

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

Apple login error -80046: [Mac Anisette migration and validation, 0.8.2](docs/zloader/APPLE-LOGIN-0.8.2.md).

UTM iOSHelper installation and ExtensionKit support: [signing correction and validation, 0.8.3](docs/zloader/EXTENSIONKIT-0.8.3.md).

Container navigation and Settings order: [single back navigation and menu placement, 0.8.4](docs/zloader/SETTINGS-0.8.4.md).

Latest changes: [installation certificate recovery and Signed IPAs, 0.7.18](docs/zloader/CERTIFICATES-SIGNED-IPAS-0.7.18.md).

Appearance and connection corrections for 0.7.20: [validation and remaining device checks](docs/zloader/UI-TUNNEL-0.7.20.md).

Sources overview and local HTTPS IPA sharing in 0.7.28: [implementation and validation](docs/zloader/LAN-INSTALLER-0.7.28.md).

Imported signing identities, account-free install/refresh and source IPA downloads in 0.7.63: [behavior and validation](docs/zloader/IMPORTED-IDENTITIES-0.7.63.md).

0.7.64 removes automatic signed-IPA exports, keeps Refresh Cache in Developer Options, and adds installer IPA icons: [review and validation](docs/zloader/REVIEW-0.7.64.md).

0.7.65 integrates Refresh Cache into the developer settings list and unifies Settings destinations: [coverage and validation](docs/zloader/SETTINGS-STYLE-0.7.65.md).
