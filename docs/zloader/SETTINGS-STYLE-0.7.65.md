# Settings presentation — 0.7.65

The Refresh Cache destination is now a normal navigation row in Developer Options'
existing Database Options section. It sits within the settings list, below the
logging/widget options, rather than above all other settings. Wireless pairing
and the IPA installer also use ordinary list rows.
The independent top-level button and two-tile shortcut layout are removed.

A shared style follows that former Refresh Cache card: themed opaque surfaces,
28-point continuous corners, 16-point row padding, eight-point row spacing,
monochrome menu symbols and native navigation chevrons. Native text styles,
labelled Toggles, selection states, swipe actions and existing bindings remain.
The app's chosen accent and system light/dark colors still apply.

## Coverage

- Root UIKit settings rows use individual rounded cards and the shared alignment.
- All 41 SwiftUI settings menu/detail source files use the shared page styling.
  Sections share the row component; native Lists replace old Forms so group
  clipping does not flatten the individual cards. Local list-style overrides
  and title-only menu labels are removed.
- Developer Options, experimental settings, operation logging and backup/restore
  use regular sectioned lists. Scrollable configuration editors and previews
  retain their editing layout with the same themed card surfaces.
- Pairing, connection/VPN setup, profiles, certificates, keys, signing identities,
  portal resources, appearance/language, storage, health, shortcuts, cache,
  wireless installer, About and pushed/sheet detail screens use those primitives.
- The older Anisette server screen, UIKit profile/certificate selectors, refresh
  history, error log/details, licenses and app-icon selection also adopt the
  same surfaces. UIKit styling is scoped to Settings tables and does not change
  unrelated app tables. Read-only log/XML content keeps its specialized format.
- System document pickers, alerts and Apple-owned authentication UI remain native.

## Validation and limits

`python3 zLoader/scripts/test-settings-style.py` checks settings destination
coverage, the integrated refresh-cache entry, labelled toggles, removed style
conflicts and the legacy UIKit destinations. Storyboard tests verify existing
outlets/actions. Release and IPA integrity checks are separate from runtime UI
verification. Actual iPhone navigation, sheets, large accessibility text,
VoiceOver and tvOS focus behavior still require device acceptance; static checks
and build success do not establish pixel-level rendering on those devices.
