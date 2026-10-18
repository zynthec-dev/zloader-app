# Account certificate recovery in 0.7.62

A Side Installer installation could leave account signing blocked by its old
certificate. Three independent shortcuts contributed: foreign active identities
bypassed account provisioning, the account setup row treated any stored P12 as
ready, and reinstall operations could select an old installed/assigned identity
again after an account certificate had been replaced.

Account certificate reuse now requires the exact certificate DER in the selected
team's live inventory, a nonexpired certificate and a cryptographically matching
private key. The issuer/installer name does not matter: a valid Side Installer
identity with its private key is reused. The running installation certificate is
considered for embedded P12 recovery before requesting a replacement, as are
other local identities. Public certificate data alone cannot sign; private keys
cannot be recovered by downloading a certificate from the portal.

The setup row exposes certificate repair when the active identity is expired,
revoked, belongs to another team's inventory or has an invalid key. Preparation
errors are shown after dismissing the progress dialog instead of merely logged.
Modern unified DEVELOPMENT certificates are included in replacement selection;
existing user-controlled revocation confirmation remains in force. Certificates
and keys are not deleted just because another usable identity is selected.

Automatic per-app identity selection must not reinstate an unusable old identity.
Explicit imported identity signing remains separate. The restriction on replacing
a zLoader installation signed by another team remains in place; this correction
does not bypass Apple authorization or claim that a private key is embedded by
all installers. Account signing other apps can use the selected account identity.

Apple documents why code signing requires both certificate and private key:
https://developer.apple.com/documentation/technotes/tn3161-inside-code-signing-certificates

AccountCertificatePolicyTests checks reuse of a valid installer identity, missing
or mismatched keys, expired/revoked/foreign certificates, and modern Apple
Development replacement classification. Existing signing, profile, revocation,
login and transport tests and the iPhone Release/package checks are also run.
Actual Side Installer identity recovery, renewal and installation require a
physical-device test. No account credentials, signing keys or device identifiers
are included in the tests or corresponding source archive.

Version/build: 0.7.62 / 0762.
