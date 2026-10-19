# 0.7.64: refresh cache, explicit IPA exports and code/UI review

## Review checklist

- [x] Repository-wide inventory and pattern scan: 475 tracked Swift files across
  host UIKit, SwiftUI features, shared code, widgets, backup helpers and tests.
- [x] Trace all automatic signing/export pipelines and the library write paths.
- [x] Review cache/thread ownership, refresh cancellation and library loading.
- [x] Review source downloads and archive extraction boundaries.
- [x] Review developer settings, library interactions and wireless installer selection.
- [x] Run documented local regression suites and Release/package validation.
- [ ] Physical-device UI, VoiceOver, lifecycle, Apple portal and install/refresh acceptance.

This is a repository-wide static scan with focused source review and build/test
validation. It is not a claim that every line or every screen was exercised on
hardware, nor a measured frame-rate or memory benchmark.

## Behavior

Only Sign App (sign-only) writes new permanent signed IPAs to the IPA library.
The Save Resigned IPAs switch, preference, operation implementation, logging row
and every automatic export pipeline step are removed. An old saved preference
has no reader and cannot re-enable the feature. Installation, refresh, re-signing
and backup helpers do not create library exports. Existing user IPAs are retained.

Internal unsigned/cached app bundles remain in their existing Payloads storage
for refresh and re-signing. Developer Options → Refresh Cache shows only these
bundles, with app icons, sizes and confirmed deletion. It has no share/export
operation. Deletion is blocked while app operations are active. IPA Library shows
only regular IPA files from ResignedApps. It does not load or enumerate the
internal refresh cache. Temporary transport IPAs remain supported when required
by the selected installation transport, and are cleaned with the operation's
private temporary directory on completion, error or cancellation.

The wireless installer IPA selector and selected-app row show app icons, names
and sizes. Missing icons use a native app placeholder. Selection uses native Buttons and text styles for VoiceOver and Dynamic Type;
physical-device accessibility acceptance remains pending.

## Applied improvements

- Library rows read only a bounded Info.plist and icon directly from the archive,
  instead of unpacking every app, executable and extension to display a list.
  Icons are downsampled to a 160-pixel thumbnail. Detailed signature/profile
  inspection remains an explicit action.
- Cache scans run off the UI actor, format sizes in the worker, and fetch Core
  Data metadata on its context queue. Library-only scans skip internal bundles.
  Refresh waits for completion; cancellation and generation checks stop older
  loads from overwriting a newer list. File-size walks notice cancellation.
- The cache-size calculation now reads view-context records on their own queue;
  operation-state reads use the same lock as writes. Self-refresh authorization
  captures the immutable team ID rather than a non-Sendable operation group.
- Library actions use native Buttons rather than a tap-only gesture. Removing the
  export switch also corrects the settings row offsets and preserves pipeline
  progress budgets.
- Archive extraction rejects absolute, parent-traversal, NUL and backslash paths
  and existing symlink components before writing. The local SideSign patch is
  versioned; upstream revision pins are unchanged.
- Source IPA hashing/copying responds to task cancellation; temporary tvOS exports
  are released by their completion callback. Raw source downloads remain available.

## Validation

README contains the full local command list, including new IPA metadata and
archive-path tests. Metadata fixtures cover host vs. extension identity, display
name, safe icon candidates, invalid data and size limits. Archive fixtures cover
normal apps/frameworks, traversal, absolute paths and an actual symlink escape.
The existing profile/device/certificate, Apple-login, transport, LAN HTTP/TLS,
project/storyboard and signing tests remain part of release validation.

Actual Apple account requests, revocations and device installation were not used
as tests. The automatic account provisioning workflow is retained. The physical
checks above remain required before claiming real-device runtime correctness.

The independent PKCS12 checks passed using OpenSSL 3.6.2 with its installed
configuration, including Unicode password, SHA256 MAC, encrypted keybag, CSR
signature and key matching. System LibreSSL 3.3.6 cannot run that full CLI test.
