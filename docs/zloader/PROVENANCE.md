# zLoader provenance and release ownership

zLoader is an independent private clone at `zynthec-dev/zLoader-ios`, maintained
by zynthec-dev. It retains the SideStore Git history and original copyright and
license notices. It is not in GitHub's fork network and does not submit these
changes to SideStore.

- Original baseline: `0dd743f75afc358b0ba4a002feb5f19474492371`, retained on `develop`.
- Development: `zloader-development`.
- Origin: https://github.com/zynthec-dev/zLoader-ios.git
- Provenance remote: https://github.com/SideStore/SideStore.git

Future zLoader updates are maintained independently and distributed through
https://altsource.zynthec.com. No automatic upstream merge or release feed is used.
Technical patches, branding and identity/source changes have separate commits.

The project, host module, targets, schemes and product directories use zLoader.
New installs use `zLoader.sqlite` and `zLoader.plist`. Existing `SideStore.sqlite`,
`AltStore.sqlite` and `AltStore.plist` are recognized to avoid abandoning data.
Protocol identifiers, existing certificate prefixes, dependency APIs and legal
attributions keep their original spelling where interoperability requires it.
New bundle IDs/App Groups can still create separate iOS containers.

Pinned submodules retain their original commits. A small reviewed local Minimuxer
warning/concurrency patch lives in `zLoader/Patches/minimuxer-warnings.patch`;
apply it with `sh zLoader/scripts/apply-dependency-patches.sh` after initialization.

Inherited upstream release/triage workflows have been replaced with a manual
zLoader artifact build, without upstream posting or publishing. Repository Actions
remain disabled until separately configured. Local IPA packaging is the validated
build path; hosted CI has not been exercised.

The source catalog pins `com.zynthec.zLoader`, offers its matching IPA, and rejects
builds that omit a pinned app. The admin allows version updates while hiding and
rejecting removal. The app always owns its self-update entry through this source;
UI deletion and backend removal of the default source are rejected.

A public binary release needs the matching corresponding-source archive, including
pinned dependency source and local patches, with clear download access. The GitHub
code repository itself can remain private. Do not publish signing credentials,
pairing files, Apple IDs, device identifiers or local build caches.
