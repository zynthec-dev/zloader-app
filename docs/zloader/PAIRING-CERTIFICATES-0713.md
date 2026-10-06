# zLoader 0.7.13: pairing, certificate exports and readable themes

## Implemented

- Semantic navigation labels and contrast-aware filled controls/source cards.
  Default mint remains dynamic in Light and Dark Mode, including older saved
  resolved mint preferences. Device screenshots of all screens remain necessary.
- The top-right Settings pairing button is removed; pairing remains available
  through the connection/pairing configuration and onboarding.
- **Lokales Pairing** starts the local server flow in onboarding. Generated remote
  pairing records are imported directly and confirmed, without a Share Sheet.
  A real native Lockdown pair request follows. Only a valid complete record is
  saved, alongside the remote record; failures preserve the existing remote file
  and offer Lockdown retry or import from iLoader. No successful Trust exchange
  or missing device metadata is fabricated. Host identities are stable locally.
- A pairing Live Activity displays status and the six-digit PIN. Tapping it opens
  the existing shared pairing session in zLoader. Completion removes the PIN.
  Lockdown-only success is not reported as successful pairing of both protocols.
- The Settings shortcut uses Apple's supported app-settings URL. iOS provides no
  public URL used here for jumping directly into Developer → Remote Pairing;
  the UI explains the remaining navigation. No private Settings URL is used.
- Native background time keeps the local server alive during a short Settings
  switch. Live Activities do not give unlimited execution: iOS expiration stops
  the session with an error instead of silently pretending pairing completed.

## Cellular endpoint changes and remaining failure

The supplied screenshot reports `DeviceEndpointNotInitialized` after the tunnel
interface becomes available, only when Wi-Fi is off. Tunnel startup is not proof
that the remote-pairing daemon is reachable.

The managed Minimuxer patch now accepts tunnel interfaces carrying both IPv4 and
IPv6, and first probes the embedded provider's known peer `10.7.0.1`, preferring
its `10.7.1.1` interface. An actual service-port TCP response is still required.
The route-reflection provider has no default Internet route or DNS override.
Its operation lease still spans the actual installation/refresh operation.

These changes correct endpoint selection; **cellular-only refresh is not yet
verified or established as fixed**. Bonjour availability, remote-pairing service
port changes, and iOS service reachability without Wi-Fi remain device checks.
No guessed port scan, artificial readiness, or removal of the existing iOS 26.4+
Lockdown/IKEv2 limitation was introduced. If iOS refuses local Lockdown pairing,
import an actual Lockdown record from iLoader; the remote record remains intact.

Acceptance: install the Apple-signed update without deleting the app; confirm
VPN permission, create both records with Trust, then install and refresh once
with Wi-Fi on and once with Wi-Fi off/cellular on. Record the active protocol,
service port and probe result if the endpoint remains unreachable. Repeat with
background/foreground transitions and overlapping operations. None of these
physical-device checks is claimed by the build results below.

## Certificate export and local key management

The pinned CodeSignKit PKCS12 builder ignored its password argument. The former
export could therefore contain an unencrypted key and no password MAC. Previously
exported files must be exported again; consider their private key unprotected.

Password-protected exports now use PBES2 / PBKDF2-HMAC-SHA256 (100,000 iterations),
AES-256-CBC encrypted PKCS8 key bags and a SHA256 PKCS12 MAC. Certificate and key
must match. Exported PEM certificates wrap actual certificate DER. Export paths
are unique and use iOS complete file protection. Password/P12 deep-link logging
has been removed. Internal legacy unencrypted P12 conversion remains distinct.

Certificates & Keys includes an app-local key vault: local RSA-2048 CSR creation,
private/public key import, matching returned certificate attachment, fingerprints,
rename, explicit deletion, and saving CSR/public/private PEM to Files. Private
PEM export explicitly warns that the file is unencrypted. Vault records use the
app's Keychain with WhenUnlockedThisDeviceOnly; private keys are not in Defaults.
Creating a CSR does not request an Apple certificate or contact Apple. The signed
certificate must subsequently be issued/imported. This is an iOS app-local vault,
not access to macOS/iOS global keychain contents; additional key algorithms and
full system Keychain Access parity are not implemented.

## Verification

- All eight existing validation scripts: PASS.
- New certificate-export test: PASS Apple SecPKCS12Import identity import with
  ASCII and Unicode passwords; wrong password and wrong private key rejected.
- Independent OpenSSL: PASS MAC/password verification, encrypted key bag,
  wrong-password rejection, local CSR signature and public/private correspondence.
- Release device build: PASS, zero warnings/errors.
- arm64 Simulator build: PASS, zero warnings/errors.
- Pinned CodeSignKit parser test: PASS ASCII/Unicode P12 imports, exact private
  key retention and wrong-password rejection. The separate macOS SwiftPM harness
  emits upstream BoringSSL integer-conversion warnings; those are not suppressed.
- Artifact hashes are recorded in VALIDATION.md. A clean build is separate from signing and device operation.
- Direct Feather import and certificate-manager UI import are not device-tested;
  the underlying pinned signing parser is verified as described above. Native Keychain persistence, PIN display, Settings
  background handoff and actual Lockdown generation require device validation.
- This Mac currently reports zero valid signing identities. No new Apple-signed
  installation or physical-device cellular test was performed for 0.7.13.
- All extension targets are retained. Entitlements still require Apple's matching
  provisioning profiles. Existing installed Bundle/App Group IDs are preserved
  through the ignored local signing configuration; no app deletion is needed.

The dependency patch is tracked separately; dependency gitlinks are unchanged.
