# Agent guidelines for zLoader

This is the user's independent private zLoader clone, not a SideStore contribution.
Original authors and licenses must remain credited. If a future task targets an
upstream contribution, follow SideStore's original participation rules from the
baseline history and establish the contributor's eligibility before generating
contribution content. Do not automate upstream PRs, issues, discussions or comments.

## Layout and builds

- `zLoader/App`: host UIKit UI, model and app management.
- `zLoader/Features`: boot, operation pipelines, SwiftUI views and transport.
- `zLoader/Shared`, `Backup`, `Widget`, `Tunnel`: shared code and embedded targets.
- `zLoader/Branding`, `Patches`, `scripts`, `Tests`: identity and local validation.
- `Dependencies`: pinned original submodules; do not change gitlinks casually.
- `zLoader.xcodeproj`: scheme `zLoader`.

Run the three local test scripts and `build-unsigned.sh` as documented in README.
Apply the tracked dependency patch before building directly in Xcode. Serialize
device/simulator builds because backup packaging shares a generated IPA path.

Preserve unrelated user edits. Swift uses four spaces, UTF-8 and LF; Makefiles use
tabs. Prefer async/await and actors. Keep signing/networking changes narrow and
document areas needing proper testing. Do not silence warning categories to claim
clean builds. Never commit pairing files, certificates, private keys, anisette data,
Apple IDs, passwords or device UDIDs. Do not bypass Apple entitlements.

Build success, ad-hoc IPA integrity, Apple signing and physical-device runtime are
separate claims. Test cellular-only behavior and iOS lifecycle on actual hardware
before claiming they work. Own releases use https://zloader.zynthec.com; preserve
its non-removable default source and the corresponding-source distribution requirement.
