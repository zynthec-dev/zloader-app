# zLoader 0.7.29

Tab bar SF Symbols use a consistent 20-point configuration rather than 24 points,
for both normal and selected states.

Profiles Management now uses the available `doc.text` symbol in the existing
22-point Settings icon canvas. The previous `doc.text.badge.checkmark` name was
invalid. Settings icon rendering falls back to `gearshape` if another requested
symbol is unavailable, rather than leaving an empty icon column.

Transport lifecycle, App Group, Core Data context and Settings storyboard checks
pass. Release build and resignable IPA packaging are validated separately.
Physical-device visual acceptance remains to be checked.
