# zLoader

Maintained by [zynthec-dev](https://github.com/zynthec-dev) in
[zLoader-ios](https://github.com/zynthec-dev/zLoader-ios).
**Based on [SideStore](https://github.com/SideStore/SideStore)**, nightly `0dd743f7`.
This is an independently maintained SideStore fork with its own development and releases.
It is not endorsed by the SideStore team; the GitHub repository remains private.

zLoader installs and refreshes apps on-device. First setup uses LocalDevVPN.
After Apple-account login, paid developer teams may opt into on-device self-signing
with an internal tunnel; free accounts continue with LocalDevVPN. zLoader requests
required capabilities and separate profiles for host/extensions from Apple and
validates the returned permissions before signing. Xcode/SSH hosts and EMProxy
controls have been removed from the app. No cellular-toggle Shortcuts or fixed
operation-duration timers. Cellular-only behavior still requires iPhone validation.

The fixed, non-removable default source is
[zynthec Apps](https://altsource.zynthec.com). zLoader self-updates use its own
`com.zynthec.zLoader` entry; SideStore releases do not replace zLoader.

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
sh zLoader/scripts/test-tunnel-payload.sh
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

For initial installation use `outputs/zLoader-resignable.ipa` (also aliased as
`zLoader-iLoader.ipa`). It contains capability metadata for App Groups/widget plus
a dormant provider archive; it needs real Apple signing by the installer, but no
installed Network Extension. After pairing/login zLoader can optionally provision
and self-sign the internal tunnel with an eligible paid team.

`outputs/zLoader-internal-resignable.ipa` includes the installed provider and requires
Network Extension authorization initially. `zLoader-unsigned.ipa` is fully unsigned
and intended for tools that supply their own entitlement/provisioning requirements.
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
