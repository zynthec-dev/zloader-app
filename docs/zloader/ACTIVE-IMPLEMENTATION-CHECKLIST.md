# Current authorized implementation — 2026-10-07

Preserve all existing native layout, spacing, icons, toggles and onboarding behavior.
Do not claim device/API acceptance based on build or static tests.

## Language and appearance
- [x] Translate German Shortcut source strings to English.
- [x] Add System / Light / Dark, accent color and System / English / Deutsch to Appearance.
- [x] System language uses iOS preferred languages, English fallback; explicit choice applies on next full app launch without interrupting operations.
- [ ] Complete English/German localization, including UIKit, SwiftUI, notifications, App Intents, widgets and privacy messages.
- [ ] Validate resource/platform membership, format arguments and source/UI coverage; compile.

## Apple Developer Portal
- [ ] Real deletion/revocation: check HTTP/result errors and verify fresh remote state before reporting success or removing local state.
- [ ] Multi-selection for App IDs, App Groups, Profiles, Devices, Certificates, iCloud Containers and further supported portal resources.
- [ ] Native iCloud container management; audit remaining portal capabilities/API limitations instead of simulated parity.
- [ ] First Developer Features entry: Developer Portal Services. Next Wireless Pairing. Next Wireless IPA Installer.

## Signing identities and sign-only
- [ ] Signing Identities directly below Account's Name / Email / Type rows.
- [ ] Import certificate with matching private key and multiple Apple-signed provisioning profiles.
- [ ] Sign-only import menu on My Apps plus button: Apple Account or imported Signing Identity.
- [ ] Additional profile import and app/extension profile assignment on signing screen.
- [ ] Wildcard profile only when exact app/certificate/team/devices/entitlements are authorized. Cannot add capability grants to imported Apple signatures.
- [ ] With authenticated matching team, allow provisioning explicit IDs/capabilities/profiles for imported certificate. Without it, require imported compatible profiles.
- [ ] Every app and extension gets its own matching profile; Apple Account route creates/reuses authorized profiles independently for each bundle.
- [ ] Sign-only always saves signed IPA to library. Separate Save Resigned IPAs toggle governs install/refresh exports, independent Signed IPAs library row below.

## Wireless IPA Installer
- [ ] Native screen: choose signed IPA, share public trust certificate, start/stop local HTTPS server, share OTA installation link.
- [ ] Local certificate recognizable device/optional team display name. Private key remains local; no credentials shared.
- [ ] Receiver manually installs/trusts CA; TLS leaf has appropriate SAN/constraints/validity. Requires compatible trusted certificate and signed IPA authorizing receiving device.
- [ ] Transfer progress and completed checkmark honestly describe served download, not unobservable OS installation confirmation.

## Final verification
- [ ] Local test suite, source checks, unsigned Release build, archive verification.
- [ ] Document remaining live Apple and physical iPhone acceptance requirements.

## Follow-up implemented in 0.7.24 — 2026-10-07

- Root Settings row symbols use aligned monochrome artwork; ordinary submenu rows remain plain, while certificate/key tools and Developer Portal resource symbols remain visible.
- Appearance has separate accent, symbol and text-field background colors. Default symbols follow the accent; default field backgrounds follow native appearance.
- Developer Portal and Wireless Pairing are adjacent cards in Developer Options. Portal entry removed from root Settings.
- Self-Pairing no longer attempts Lockdown pairing. Pairing Management retains missing-file status and manual combined/individual file import. No changes to iLoader.
- Imported Signing Identities store references to locally secured certificates/private keys and multiple profiles, with key/certificate and profile-certificate checks.
- Sign IPA has a separate My Apps navigation button beside Add. Apple Account and imported identity paths validate requested entitlements for every component, with wildcard expansion restricted to bundle matching.
- IPA Library is on the right in My Apps, removed from root Settings. The Add menu offers Files, URL and Library. Library context menus offer Install, Share and Delete. The Save Resigned IPAs toggle remains independent; sign-only always saves its output.
- Suggested sources use SideStore's original https://sidestore.io/default-sources/ catalogue. The non-removable zLoader source remains https://zloader.zynthec.com. Individual unreachable recommended feeds are not reported as a successful empty list when every feed fails.
- Local tests for transport, App Groups, operation contexts, pairing imports, managed signing, embedded profile reuse, packet-tunnel provisioning, Settings storyboard wiring and project configuration pass. Release builds and package generation succeed; physical device and live portal acceptance remain separate.

The unchecked items above remain a backlog, not a claim of completion. In particular, local HTTPS OTA installation, iCloud resource management, live portal deletion/revocation acceptance, full localization source coverage and cellular hardware acceptance remain outstanding. Provisioning an imported certificate via an authenticated matching team is not implemented by the new imported-identity signing path; that path requires compatible imported profiles.

## Additional UI/JIT/distribution changes in 0.7.24

- Native iOS 26 glass buttons and regular glass materials replace explicit custom button/card fills. SwiftUI Section row backgrounds, root UIKit Settings cards, and text fields use native glass. OS accessibility/material preferences stay in control; the implementation contains pre-26 native fallback surfaces.
- **Older-device limitation:** the Release deployment target stays iOS 26.5 because the pinned binary dependencies encode that minimum. A trial iOS-17 compilation also identified unguarded inherited newer APIs. The fallback UI code does not make the current IPA installable on pre-26 devices; older deployment requires rebuilding/replacing the binary artifacts and auditing those API availability sites. No minimum-version metadata was falsified.
- Background image functionality was removed at the user's request. Native system backgrounds are used throughout.
- The no-update card has a centered green checkmark and localized “All Apps Up to Date” label, expanded height and VoiceOver description. Unsupported-update warnings remain intact.
- Profile dump holds a transport lease over readiness and export, verifies that an archive exists, and presents its URL for sharing. Device-service/protocol access still requires physical verification; unsupported service errors are not converted into success.
- My Apps stores an “Enable JIT Automatically” preference per app and shows its menu checkmark. Opening through zLoader launches the target then performs the existing JIT operation with bounded background execution time. This is a preference, not persistent JIT authorization.
- Enable JIT is an App Intent with installed-app selection and background mode. Configure Shortcuts' personal App/Is Opened automation with the same selected app. The integrated tunnel follows the operation lease and disconnects after debug attach/detach. JIT persists for the target process; no perpetual daemon or true process-termination automation is claimed. External VPN control remains the user's Shortcuts sequence. Notifications require OS permission; iOS may deny/suspend background execution.
- The installing team owns the store's installed profile. Refresh All/background refresh exclude zLoader when the active team is missing or differs from the embedded profile. Direct refresh/resign/update/reinstall are guarded before provisioning; the menu disables refresh/resign for a mismatched team. Other apps remain signable by the selected account, and existing expiry data is unchanged. Team identity can be verified from Apple's profile; an Apple ID email is not present in that profile, so membership within the same team is not an email-level ownership test.
- Sign-only Apple Account provisioning includes eligible registered devices of the appropriate platform, checks every returned host/extension profile for that coverage, and replaces only incompatible profiles owned by this managed flow. When Save Resigned IPAs is enabled, zLoader resigning also requests that registered-device coverage and exports the IPA through the existing operation step. Imported identities keep the device/capability limits of their supplied Apple-signed profiles.

Live Apple portal transactions, JIT Shortcuts while another app is foreground, cellular-only endpoint access, installation on another authorized device remain physical/account acceptance checks. Local HTTPS OTA delivery is still outstanding; the IPA library's sharing menu does not itself create an HTTPS server.

## Private-key distribution protection

The inherited EmbedSigningCertOperation previously embedded ALTCertificate.p12 in signed bundles. New signing removes that file from the host and extensions before creating the new resource seal, and embeds only public DER in the normal operation pipeline. The sign-only path also strips inherited ALTCertificate.p12 files before signing. Personal refresh uses the active private key retained in the local Keychain. Existing saved IPA files are not edited after signing; old exports may still contain that key archive and must be newly signed before distribution. This change prevents the known automatic key embedding; arbitrary third-party IPA contents are not a general secret-scanning guarantee.
