# Launcher installation and validity — 0.7.52

Pending installations and installed active apps now share a flattened grid. Pending
cells have no InstalledApp record, so taps and context menus ignore them. Nested
index-path translation keeps icon prefetching aligned with the installed record.
Changes to the active fetched records and pending tiles coalesce into one deferred
reload rather than mixing transient section reloads with Core Data insert batches.

Normal device installs save the app record immediately after successful installation,
before later pipeline steps. The pipeline saves before removing progress and
propagates save failures instead of reporting success with an invisible app. Only
replacement of the running bundle uses the self-update process-exit path.

Remaining days include an incomplete final day: 364 days and 23 hours display as
365 days. The earliest actual host/extension/certificate expiration still applies.
Reusing an existing matching profile does not extend its authorization; a refresh
cannot manufacture a new 365-day validity period.

Validation: transport, App Group, context confinement and expiry helper tests;
arm64 Release build and bootstrap package integrity. Physical acceptance remains:
install an ordinary app into a partially occupied row, confirm no host termination,
reopen zLoader and confirm the installed tile persists. Refresh and compare the
shown days with the actual profile/certificate expiry. Also confirm self-update
still hands replacement of the running executable to iOS.
