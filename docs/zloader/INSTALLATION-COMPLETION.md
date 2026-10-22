# Completion of third-party app installations

Ordinary app installation must leave zLoader in the foreground. The explicit
process-exit path is reserved for replacement of the exact running bundle ID,
after installation_proxy accepts the self-update. The low-level self-update
entry point now validates this identity again before calling the gateway.

The installation pipeline previously returned its background-context InstalledApp
directly to UIKit completion handlers and read its bundle identifier outside the
context queue. Completion now transfers only a saved permanent object ID and
resolves a distinct instance in the UI's view context. Source identity reads and
saves happen on the source context queue. Early failures and cancellation are
delivered on MainActor too. The handoff is selected from the actual installation
steps, including re-signing and activation. Operations without an installation
retain their existing result semantics. Callback ordering is preserved.

The single-operation completion closure no longer strongly captures its own
RefreshGroup. That cycle could retain completed groups and their database and
shared signing contexts after repeated operations.

Regression tests use a real in-memory Core Data store with separate writer/UI
contexts, force a UI fault/read and reject unsaved installation results. They run
with Core Data concurrency assertions enabled. Existing self-replacement identity
tests continue to distinguish the running store from foreign apps and Backup.

These source-level defects are confirmed by inspection; the user's reported
process termination has not yet been correlated with an iPhone crash report.
Physical validation is still required: install a foreign app and verify zLoader
remains visible; then update the running zLoader and verify that it exits only
after iOS accepts the replacement and that installation completes.
