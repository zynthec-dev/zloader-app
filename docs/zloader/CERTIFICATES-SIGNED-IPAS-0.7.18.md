# zLoader 0.7.18: installation identity and signed IPA library

The certificate manager and Developer Account have an explicit “Zertifikate aus
dem Account” entry. It opens a separate remote inventory, with local import and
public-certificate file download. Refreshing the local certificate manager does
not populate it with every remote certificate. Apple does not return private keys.

On launch, zLoader extracts the actual running executable's leaf signing
certificate, imports it locally and attempts to activate it when no signing
identity is already active. Activation requires a matching, usable private key
from the local certificate store, the local key vault or an installer-provided
embedded P12. The installed leaf is authoritative; stale installer serial metadata
and unrelated provisioning-profile certificates do not choose the identity.
Embedded P12 serial mismatches are now rejected rather than returning another
identity. Expired installation certificates are not automatically activated.

If the private key is absent (usually after Xcode installation), the manager
shows the detected installation certificate and explains the matching P12 import.
Importing its key activates it automatically when no other identity is active.
Existing manually selected identities are preserved. Explicit local deletion or
deactivation is respected across reloads; a manual re-import restores a deleted
record. No automatic certificate creation or portal mutation is part of boot.
The authenticated signing flow also reads the executable's actual certificate
before falling back to legacy installer metadata.

“Signed IPAs” / “Signierte IPAs” is a normal Settings entry immediately after
Change App Icon. The submenu lists the existing Documents/ResignedApps exports,
allows tapping to share/save, context-menu deletion and enabling future signed-IPA
exports. Turning off export retains existing files. The old experimental cache
entry is removed. The full technical Storage Explorer remains available separately.
The new library text has English and German catalog translations and follows the
app/system locale; other languages fall back to English.

The app contains no Xcode-host/SSH integration or WireGuard/EMProxy settings.
The Xcode source project and local Mac build/signing scripts remain development
tools, not app features. LocalDevVPN bootstrap and the optional paid-team internal
tunnel remain as documented for 0.7.17.

Validation is compile/package and local cryptographic verification. Automatic
recovery with a real installer-provided P12, account certificate downloads,
certificate activation after key import and visual device navigation still need
iPhone acceptance testing. No private key can be recovered from a public certificate.

Local checks on 2026-10-07: transport, App Groups, operation context, managed signing,
profile reuse/authorization, pairing import, storyboard/project structure and
provider-integrity checks passed. Certificate tests passed Apple Security,
independent OpenSSL and the actual pinned CodeSignKit import path, including
Unicode passwords and rejection of mismatched keys. The final Release build succeeded with no warning/error lines in its log.
Bootstrap/internal IPA structure validation and the bundled English/German
Signed IPAs texts also passed. These checks do not exercise a live
account download or recovery from a real iPhone installation.

## 0.7.19 onboarding adjustment

The initial LocalDevVPN step restores the earlier icon/title, short description,
Verify VPN and bottom Continue/Set Up Later layout. Shortcut configuration remains
available as collapsed sections; expanding them scrolls rather than clipping the
screen. Connection checks use the asynchronous endpoint refresh and do not restore
the former fixed delayed rechecks. An already selected authorized internal tunnel
is checked with a live device-service request.

Connection Configuration keeps LocalDevVPN controls and its shortcut settings
visible but disabled/dimmed when the internal connection is selected. External
peer probes are also suppressed there. Selecting external enables editing again;
existing shortcut names remain stored. Operation hooks still skip internal transport.
