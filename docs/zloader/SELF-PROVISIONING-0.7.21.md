# Self-provisioning recovery in 0.7.21

A live provisioning attempt must not be interpreted as a failed replacement merely because its durable pending flag is set. The onboarding view now avoids recovery checks during an active attempt, clears stale view-local messages at a new start, shows real group progress and exposes cooperative cancellation before installation. Cancellation waits for the operation callback rather than falsely clearing the busy flag while installation continues.

The installed app is verified on reopening. An unresolved marker without an authorized running provider is reported as an interrupted or incomplete attempt, rather than claiming a new installation already failed. Failed recovery markers are cleared so a retry is explicit.

The user confirmed that the observed installation completed after fully closing the app; switching to the home screen did not suffice. The installation phase explains this. The current Idevice FFI callback supplies PercentComplete, not a validated safe-to-terminate status. No guessed percentage, delay or forced process exit was added. The existing general self-install suspension path remains unchanged. Public iOS APIs provide no graceful terminate-and-relaunch operation; exit bypasses normal lifecycle cleanup (Apple QA1561).

Validation: signing-disabled Release build, transport/App Group/context/managed-signing/tunnel-provisioning/payload tests and IPA integrity checks. The revised UI and cancellation path still need device acceptance testing. The user's completion report applies to the preceding build and does not establish all cellular, VPN or cancellation cases.
