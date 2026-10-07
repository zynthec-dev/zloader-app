# zLoader 0.7.30

The canonical zLoader entry is pinned first in Sources → All Apps. Other apps
retain the selected sorting order. Search and category filters still apply: a
query that excludes zLoader does not force an unrelated result into the list.
Duplicate bundle IDs from other sources are not treated as the canonical entry.

This uses a display-only adapter over the existing fetched-results controller,
without changing the Core Data schema or source catalogue order. Item selection,
context-menu previews, icon prefetching and post-install cell reloads use the same
display index mapping. Catalogue changes reload the pinned snapshot rather than
applying untransformed database indices as collection-view batch changes.

Retains the smaller tab bar icons and restored Profiles Management icon from
0.7.29. The Source description is updated as requested; release notes continue
to link the matching public corresponding source.

Transport, App Group and context checks passed. The device Release build and IPA
integrity are validated separately. Physical-device UI acceptance remains open.
