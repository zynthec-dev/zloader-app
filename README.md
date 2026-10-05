# zLoader

Maintained by [zynthec-dev](https://github.com/zynthec-dev) in
[zLoader-ios](https://github.com/zynthec-dev/zLoader-ios).
**Based on [SideStore](https://github.com/SideStore/SideStore)**, nightly `0dd743f7`.
This is an independent clone with its own development and releases.

zLoader installs and refreshes apps on-device. The embedded local packet tunnel
is started when a device operation needs it and retained until its active
operations finish. Cellular toggle Shortcuts and fixed transport-duration timers
are removed. Mint Light/Dark styling and three alternative icons are included.
Cellular-only installation and refresh remain experimental until tested on an iPhone.

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
sh zLoader/scripts/build-unsigned.sh
```

Open `zLoader.xcodeproj`, scheme `zLoader`. The dependency patch must also be
applied before a direct Xcode build. It is tracked separately, idempotent and
leaves the original dependency gitlinks intact.

For installing through iLoader, use `outputs/zLoader-iLoader.ipa` and read
[the verified iLoader signing limitations](docs/zloader/ILOADER.md).
For importing into SideStore, `outputs/zLoader-resignable.ipa` has the same metadata. It contains
ad-hoc signatures preserving capability requests for the importer. It still
requires valid Apple provisioning and signing, including its widget and tunnel.
The paid account must authorize App Groups and Network Extension for the relevant
profiles. A paid membership alone does not establish that the signed IPA has
these capabilities. Keep extensions when importing. The separate unsigned IPA
is for inspection and does not establish device installability.

- [Transport and iOS constraints](docs/zloader/TRANSPORT.md)
- [Build validation and device acceptance](docs/zloader/VALIDATION.md)
- [App Group startup and signing](docs/zloader/APP-GROUPS.md)
- [Provenance and own release source](docs/zloader/PROVENANCE.md)

License: [AGPL-3.0](LICENSE). Original copyrights and dependency licenses remain
in source and About, including SideStore, AltStore and LocalDevVPN/StosVPN credits.
Distribution must include access to the corresponding source. No entitlement
or signing bypass is provided.
