# Upstream integration

App: **zLoader**. Repository: **zynthec-dev/zLoader-ios** (private).
Maintainer: **zynthec-dev**. The local development branch preserves SideStore ancestry.
This is an independent private repository preserving Git history, not a GitHub
public fork-network entry (GitHub public forks cannot be made private).

- `develop`: unmodified SideStore baseline at `0dd743f7`.
- `zloader-development`: downstream implementation and branding.
- `upstream`: https://github.com/SideStore/SideStore.git
- `origin`: https://github.com/zynthec-dev/zLoader-ios.git

The upstream Xcode target/module `SideStore`, source folders, database names,
URL schemes, serialization keys and pinned submodule gitlinks remain stable.
The user-facing scheme is `zLoader`; product and bundle identifiers come from
`zLoader/Branding.xcconfig`. Technical transport changes and branding use
separate commits. Full conflict-free future merging cannot be guaranteed.

## Bringing in a later nightly

```sh
git fetch upstream --tags
# Inspect the updated tag / release before selecting a concrete commit.
git switch zloader-development
git merge <verified-upstream-nightly-sha>
git submodule update --init --recursive
sh zLoader/scripts/test-transport.sh
sh zLoader/scripts/test-app-groups.sh
sh zLoader/scripts/build-unsigned.sh
```

Resolve upstream changes to pipeline ownership, readiness checks, profile
capabilities and extension packaging before rebranding. Never blindly update
submodules to their branch heads. Inspect new upstream entitlements and protocol
requirements. Preserve copyright headers and bundled licenses. Any future
upstream contribution must follow SideStore's human contribution policies.

Original `.github/workflows` and Makefile publishing automation are preserved.
They contain SideStore product names and upstream publishing destinations and
are NOT the fork's release process. GitHub Actions is disabled for this repository pending an explicit fork-specific
release configuration. The user approved uploading the source and configuring
the repository. The local
scripts above package both an unsigned review artifact and a resignable IPA.
The latter uses local ad-hoc signatures solely to preserve capability requests
for SideStore import; it is not an authorized iOS installation signature.
Do not run the inherited `make fakesign ipa` as a zLoader release workflow.

## Identity and sources

The UI includes maintainer, repository and a clear “Based on SideStore” link.
Community app feeds remain identified as SideStore community sources; they
must not be misrepresented as zLoader's official distribution. The fork has no
published update feed or release yet. Its own bundle ID does not match the
upstream SideStore app entry, so upstream SideStore IPAs must not replace it as
an alleged zLoader update. New bundle IDs create separate iOS containers;
existing SideStore data is not automatically migrated.
