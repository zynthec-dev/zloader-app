# Installation and refresh handoff

Explicit Apple-account refresh and re-sign renew an owned paid-team profile even
when its downloaded copy is valid. A foreign managed profile is preserved; zLoader
creates its own certificate-bound profile instead of modifying somebody else's.
Ordinary installation may reuse a compatible profile. Free accounts retain Apple's
Xcode team-profile issuance path. Imported profiles cannot extend their Apple-issued
expiry. Certificate expiry still limits the displayed remaining time.

After profile injection succeeds, refreshed profile data is also written into the
private refresh cache. It is not an IPA-library item or a signed-IPA export.

Self replacement checks the actual signed bundle ID separately from the AFC
staging-directory identifier. Its transport-only handoff flag is removed locally
and is never sent as an Apple option. The callback runs after the complete framed
Install command has been written and flushed, before waiting for an installer
response. Waiting for progress can deadlock on an OS that waits for the running
executable to exit before reporting progress. Write failures do not exit the host.
Submission does not prove Apple's later verification or successful installation;
the staged record is reconciled against the real installed bundle on next launch.

Foreign-app installation never requests process exit. If iOS backgrounds an
installation that began in the foreground, successful completion requests one
native activation of zLoader by bundle ID. Background operations do not activate
zLoader. No URL handler or Safari fallback is used.

Rust tests exercise the actual serialized Install command with a silent mocked
transport, checking flush-before-callback, write failure, ordinary-install isolation
and local flag removal. Real installd, SpringBoard and profile renewal require
physical-device acceptance testing; Simulator's device-transport functions are
explicit no-ops and cannot prove these behaviors.
