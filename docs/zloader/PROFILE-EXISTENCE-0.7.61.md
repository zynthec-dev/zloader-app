# Fresh portal profile checks in 0.7.61

A deleted portal profile was not recreated on the next signing/install operation
because the paid-team provisioning flow returned a compatible installed/local
copy before requesting Apple's profile inventory. Assigned profiles had another
local-only early return. A profile's signature and expiration cannot establish
that its portal record still exists.

The Apple-account signing flow now resolves profiles through the portal for
every host and extension, including previously assigned profiles. Paid teams
list profiles freshly, download and validate relevant candidates, reuse a
compatible remote profile, renew an incompatible owned profile, or create a
new certificate/device-bound profile when no usable remote profile exists.
Assigned UUIDs are preferences within that live inventory, never proof of
existence. The assigned host bundle ID and selected team remain fixed when a
deleted profile is replaced. Replacement assignments are persisted after installation. Local and
installed copies cannot bypass portal resolution. Free teams retain Apple's
on-demand Xcode profile download/generation on each operation.

Portal read failures propagate rather than authorizing a stale local copy or
issuing duplicates based on an assumption of absence. Capability, certificate,
team, device, expiry and extension-identity checks remain enforced. Unrelated
portal profiles are not regenerated. The normal imported-identity signing
path outside this Apple-account provisioning flow is not modified.

`PortalProfileResolverTests.swift` drives the production resolver against a
mutable portal fixture. It covers delete/re-sign/reuse with a still-valid
installed copy, fresh listing/download on subsequent resolution, inventory and
download failures, renewal ownership/team boundaries and compatible duplicate
selection. Existing entitlement and embedded-profile authorization tests are
run separately, as are the project checks and device Release build.
Actual portal recreation, signing and installation must still be verified on
a physical device. No account or device secrets are used by local tests.

Version/build: 0.7.61 / 0761.
