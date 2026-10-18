# zLoader 0.7.56: source migration and signing build fix

The fixed update source is now https://source.zloader.de. Startup recognizes the
previous fixed source identifiers and updates the existing source in place,
including its app/news identifiers. The default source remains non-removable.
Future releases use the new source as recorded in `RELEASE-PUBLISHING.md`.

The managed SideSign patch referenced `SigningEntitlements`, but its implementation
was missing from the dependency patches. The additional
`sidesign-signing-entitlements.patch` supplies the public helper used by SideSign
and the host app. The patch application script installs it idempotently without
changing the pinned submodule commit.

The helper selects the profile's application identity, expands a wildcard only
for a compatible target bundle ID, remaps requested keychain/App Groups, and
rejects capabilities or values not authorized by the selected Apple profile.
It copies no unused profile capabilities into the signed app. Existing signing
tests now also cover incompatible identities, team mismatch, foreign groups,
partial array authorization, push environments and Boolean/number mismatches.

The marketing version is `0.7.56`; the build number is `0756`.
The intended local sideloading artifact is `outputs/zLoader-0.7.56-resignable.ipa`.
It requires Apple signing and matching host/widget profiles before installation.
Signing on a physical device and migration of an installed database need device
validation; a local build does not establish those runtime claims.

## Local validation

Passed managed-signing, embedded-profile-reuse, transport, transport-status,
App Group and project-configuration checks. The helper patch was also applied in
a fresh temporary directory and compared with the compiled dependency source;
repeated application of all dependency patches succeeded.

`build-unsigned.sh` completed successfully, including unsigned/resignable IPA
packaging. `test-bootstrap-package.py` verified the external-only package layout,
host/widget entitlement metadata and strict local signature integrity. Direct
archive inspection confirmed host/widget version `0.7.56` / `0756`, bundle ID
`com.zynthec.zLoader`, the new source URL and the legacy migration URL in the
compiled host. The IPA hash matches the generated manifest:

```text
b4b3ff82884c2b488b7c438625a59c24540d29476688000c4ce7b39b7d02e3a5
```

No Apple signing credentials were used and no binary was published.
