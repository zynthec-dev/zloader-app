# Pending installation visibility — 0.7.53

Publish per-app progress before entering shortcut hooks, acquiring the tunnel lease
or checking the device endpoint. Previously a pending tile did not exist until all
transport preparation completed. Clear that progress even if setup fails or is
cancelled before the pipeline begins.

The launcher now consumes the pending dictionary delivered by the publisher on
DispatchQueue.main instead of rereading a dictionary being mutated on a worker
queue. Deferred reloads still coalesce pending and persisted records into one grid.

`test-launcher-grid.sh` exercises the actual composite/dynamic collection data
sources in a booted arm64 iOS simulator: shared item count, pending-cell rendering,
nested index translation and transition to an installed record. This does not
perform real Apple signing or device installation. Required iPhone acceptance:
start a new install, verify its dimmed tile during tunnel preparation, signing and
installation, then confirm one persistent tile after completion and relaunch.
