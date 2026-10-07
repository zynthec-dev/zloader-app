# Sign-only managed provisioning correction, 0.7.31

Apple error 9401 for an original third-party identifier (for example
`com.frizz-lm.sideinstaller`) means that identifier is unavailable for the selected
team. Creating profiles for every registered device does not make an unavailable
App ID registrable.

The sign-only path already called FetchProvisioningProfilesOperation but disabled
team suffixes. It then matched issued profiles against the unchanged input IDs.
This differed from installation: third-party original IDs could fail registration,
and simply enabling suffixes would subsequently fail profile matching.

Apple Account signing now enables the installation identity-resolution policy
and uses the same ResignAppOperation to prepare the app, extensions, plist
references and requested entitlements before signing. Each component has a
separate issued profile. Existing zLoader self-identity preservation remains in
the shared provisioning operation. Imported identities continue to use their
explicit compatible imported profiles; no portal mutation is added to that path.

Sign-only sets embedSigningCertificate to false and removes any old
ALTCertificate.p12 input archives. Exported IPAs must not contain a private signing
identity. Only successful signed outputs are saved to the IPA library.

Paid-team sign-only requests all eligible enabled registered iPhone/iPad devices.
Free provisioning continues to use Apple's returned free-account profiles. Neither
device coverage nor a paid account overrides Apple's capability authorization.

Managed-signing, portal capability, transport, App Group and context tests passed.
Release build and bootstrap archive checks are separate from device validation.
The decisive acceptance test is to sign the reported SideInstaller IPA using the
paid Apple Account, confirm the generated parent/extension IDs and profiles in
the portal, and install the result on an authorized receiving device. This live
Apple/device flow has not been executed by this code-only correction.

Retains the smaller tab icons, Profiles Management symbol and pinned zLoader
All Apps entry from the preceding changes. The latest requested source description
is published with this release.
