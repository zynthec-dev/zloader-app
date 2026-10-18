# Apple login compatibility in 0.7.57

The reported Apple error `-80045` matches the GrandSlam compatibility issue
addressed by SideStore after Apple's October 12 login changes. The pinned
SideSign version predates both the GrandSlam client-info correction and support
for automatically pushed verification codes without an `au` field.

The local dependency patch retains the pinned submodule commit and original
copyrights. Its 2FA changes are adapted from NiceAesth's SideSign PR #5
(commits `567ddca9e696c389cae49ae3f3643d72fe341de3` and
`7a18c89e491600d78a84a889eebb20fd5cfdfe5e`). The client-info behavior follows
SideStore commit `34f61f2`:

- https://github.com/SideStore/SideSign/pull/5
- https://github.com/SideStore/SideStore/commit/34f61f2

`AppleLoginCompatibility` scopes the Android ADI client descriptor to HTTPS
`gsa.apple.com/grandslam/` requests, including trusted-code validation. The
`/auth/verify/` and other endpoints retain their original anisette client info.
It recognizes status `hsc = 409` with no explicit authentication type as an
already pushed code, opens code entry without requesting another delivery, and
limits the recursive pushed-code retry to one per login task. Explicit trusted
device, SMS, voice and account-repair responses retain precedence.

`test-apple-login.sh` checks endpoint identity boundaries, legacy and pushed-code
response selection, and task-local retry-state inheritance/reset using Swift 6.
The patch is applied by the existing dependency patch script and is idempotent.
Version/build are `0.7.57` / `0757` so the published 0.7.56 artifact is not replaced.

Real Apple-account authentication, automatically pushed verification codes and
SMS-only accounts require physical-device validation. No account credentials or
verification codes are used by the local tests. This remains an upstream-derived
compatibility workaround, not a claim of Apple API stability.

## Local validation

Passed the Apple-login compatibility tests, managed-signing, transport,
transport-status, App Group and project-configuration checks. Applying the
login patch to the original authentication source in a fresh directory produced
the exact compiled sources; repeated dependency-patch application also passed.
The unsigned build and resignable packaging completed successfully.
`test-bootstrap-package.py` verified the nested ad-hoc signatures and App Group
metadata. Archive inspection confirmed version/build 0.7.57/0757 for host and
widget, the new source URL, and the compiled login-compatibility code.

Local IPA: `outputs/zLoader-0.7.57-resignable.ipa`.
SHA-256: `4ab696c122ff72c80cf2776fd722c8a334298a9ffadd2c118b6a784f97439832`.
No new public release has been made as part of this login correction.
