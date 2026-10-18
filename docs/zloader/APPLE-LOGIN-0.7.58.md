# Apple login HTTP 503 handling in 0.7.58

The installed 0.7.57 returned Apple's HTML HTTP 503 response immediately after
Sign in, before code entry. This timing alone does not identify whether the
initialization or password-proof request failed. The previous generic parser
error hid that distinction.

The existing tracked SideSign patch now reports non-plist HTTP failures with
the status and authentication phase, without displaying the server's HTML.
Structured Apple error responses retain their original error codes.

Only an HTTP 503 during SRP initialization allows one fresh authentication
attempt after at least five seconds, using a Windows AuthKit descriptor.
Retry-After numeric values up to 30 seconds are respected; longer or malformed
numeric delays do not permit this fallback. The fallback remains scoped to the
current task and GrandSlam endpoints. Verification endpoints retain their
original anisette identity. Password proofs, app tokens, verification codes,
other HTTP errors and subsequent Windows failures are never retried by this
policy. Cancellation stops the delayed attempt. Existing 2FA handling remains.

The descriptor and temporary 503 observations are documented by contributors
in https://github.com/Dadoum/anisette-v3-server/issues/61 (October 16, 2026).
This is a compatibility workaround based on those reports, not proof that the
reported device failure has been resolved. Apple's private API can change.
Original SideStore and SideSign authors and licenses remain credited.

Swift 6 policy tests cover identity boundaries, task-local inheritance/reset,
the single initialization fallback, Retry-After bounds, cancellation, and
non-replay of proof/token/error responses. The delay uses the nanosecond API
for compatibility with the project's pre-iOS-16 deployment target. The local
build and package checks are separate from an actual Apple-account login;
that must still be checked on the user's iPhone after installing this update.
