# HTTP 503 during password verification in 0.7.60

A device using a free Apple account reported `Apple returned HTTP 503 while
verifying sign-in`. That identifies a non-plist/empty HTTP failure during the
SRP `complete` request, before account/team/profile provisioning. It does not
establish that a free account itself is the cause.

The 0.7.58 fallback covered only initialization. Version 0.7.60 extends the same
bounded policy to a 503 during SRP proof: wait at least five seconds, then invoke
`authenticate` afresh using the scoped Windows identity. This creates a new
SRP client/public key and obtains a new challenge before computing another
proof. It never resends the previous `complete` payload or any verification
code. The fallback identity is retained through that entire new exchange.

A task-local guard allows only one fallback across initialization and proof.
App-token and code-validation failures, structured Apple credential errors,
other HTTP statuses and failures in the Windows attempt are not retried by this
policy. Cancellation and bounded numeric Retry-After handling remain intact.
The working paid-team revocation correction from 0.7.59 is retained.

A first-hand compatibility report describes Windows GrandSlam identity and
retrying the entire SRP exchange after transient HTML 503 responses:
https://github.com/Dadoum/anisette-v3-server/issues/61
(The relevant report is the October 16, 2026 comment by xPudda; see issue #61.)
This is a compatibility workaround; it does not prove a successful login for
the affected account or guarantee Apple's private API behavior.

Swift 6 policy tests cover both initialization and proof 503 eligibility,
identity boundaries, task-local inheritance/reset, cancellation, bounded delay,
rejection of token/code phases and non-503 statuses, and prevention of a second
fallback. Patch reproduction and the required project/signing/transport tests
are run separately from the iPhone Release build and package verification.
An actual free-account login still requires the user's physical-device test.

Version/build: 0.7.60 / 0760.
