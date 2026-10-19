# Settings account labels in 0.7.66

The 0.7.65 icon layout moved each native label's leading edge while retaining its
previous trailing edge. UIKit had already sized the account field names to their
intrinsic widths, so this shortened “Name”, “Email” and “Type” to an ellipsis.

Account rows now stack the field name above its value. Their heights are measured
using the same available width and Dynamic Type fonts as the layout. Both labels
can wrap, and values use natural text alignment. Other native settings titles use
the available content width rather than subtracting the icon inset from their
old label widths. Subtitle rows retain their existing vertical layout.

Validation: settings style, storyboard wiring and project configuration checks;
transport, app-group and operation-context regressions; iPhoneOS Release build;
resignable IPA metadata and ad-hoc integrity checks. This does not establish
physical-device rendering, accessibility acceptance or Apple signing validity.
