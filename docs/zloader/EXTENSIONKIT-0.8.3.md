# ExtensionKit signing and UTM, zLoader 0.8.3

The reported UTM installation failure (`MinimuxerError 36`, underlying
`IXErrorDomain` code 8) comes from inconsistent bundle identities: the host was
renamed for the selected developer team, while `com.utmapp.UTM.iOSHelper` retained
its original ID. Apple's installer requires the helper ID to start with its
containing app's final ID.

The official UTM 5.0.8 IPA places this helper at
`Payload/UTM.app/Extensions/iOSHelper.appex`, using
`EXAppExtensionAttributes.EXExtensionPointIdentifier` rather than `NSExtension`.
zLoader's component discovery previously included only `PlugIns/*.appex` and
Watch apps. It consequently missed ExtensionKit helpers when resolving profiles,
rewriting metadata, selecting entitlements and caching component metadata.

## Change

A shared discovery function now includes both `PlugIns/` and `Extensions/`,
recurses through signing components and retains the existing Watch handling.
Extension enumeration in the app model, extension management and bundle inspectors
uses this function as well. Each discovered component follows the existing
per-component Apple profile and entitlement validation. The helper is preserved;
it is not removed to work around the install error. A final bundle-identity check
rejects stale child IDs and duplicate IDs before signing.

For a synthetic team suffix `QA12345678`, the final identities are:

- Host: `com.utmapp.UTM.QA12345678`
- Helper: `com.utmapp.UTM.QA12345678.iOSHelper`

Extension point identifiers remain unchanged: they identify the protocol matched
by UTM's executable, not the helper's signing identity. No Apple capability or
profile requirement is bypassed. The dependency gitlinks remain unchanged;
`sidesign-extensionkit.patch` reproduces the dependency changes after the existing
tracked patches.

## Verified

- The old component walker reproduces the missing helper using the actual
  Info.plists from the official UTM 5.0.8 release.
- The corrected walker discovers and rewrites the actual UTM host and helper.
- Synthetic fixtures cover classic, ExtensionKit and nested extensions, duplicate
  filenames, internal aliases and rejected external symlinks. The screenshot's
  stale-child-ID failure is detected before signing.
- The actual pinned CodeSignKit signs a synthetic host/helper pair with separate
  final bundle identities and entitlement ownership. Apple's `codesign` verifies
  the complete package and the helper's signed entitlements.
- All 32 local regression scripts pass, as do the official UTM metadata fixture,
  clean dependency patch reproduction, iPhoneOS Release build and strict resignable
  IPA package checks.

Official fixture: [UTM 5.0.8](https://github.com/utmapp/UTM/releases/tag/v5.0.8),
`UTM.ipa`, 150556413 bytes, SHA-256
`4875a1ec869278fb173b37467388ea627bfa6d95f1d64501bc41bb86dd7d53b2`.
The fixture is local test input and is not included in zLoader's release or source
archive. The corresponding source retains original authors and licenses.

## Device acceptance still required

After updating zLoader, import the original UTM IPA again so it is signed afresh.
Do not reuse an IPA exported by the old signing path. Actual Apple-portal profile
issuance, UTM installation, helper execution/snapshots, JIT and self-update on an
iPhone remain unverified by these local tests.

References:
[UTM's helper architecture](https://github.com/utmapp/UTM/blob/main/Documentation/Architecture.md),
[Apple bundle ID requirements](https://help.apple.com/xcode/mac/current/en.lproj/deve70ea917b.html).
