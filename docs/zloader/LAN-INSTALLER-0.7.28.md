# zLoader 0.7.28

Sources now has an **All Apps** button (German **Alle Apps**). It reuses the
existing Core Data catalogue, search, sorting, installation actions and app detail
controller, with compact app cards rather than screenshot galleries. It includes
apps from every added source, subject to the existing source visibility rules.
The non-removable zLoader source is named **zLoader** and stays first. A separate
sorting button opens a draggable list for the other sources; its order persists
across source updates.

The signing screen is **Sign App / App signieren** and no longer inherits the
My Apps transport status dot. The tab bar uses matching-size modern symbols,
including a package for Sources and an A monogram for My Apps.

## Wireless IPA Installer

Developer Features has a third card beside Wireless Pairing. Choose an already
signed IPA from the library, share the HTTPS trust profile, and start the local
server. Share its installation link with a device on the same Wi-Fi. The sender
must leave this screen open. Backgrounding or leaving it stops the listener,
connections and transfer copy and restores the prior idle-timer setting.

A device-local RSA CA is stored in a device-only Keychain item. Only its public
certificate is exported in the trust profile. Each session uses a separate short
lived server identity with an IPv4 SAN and serverAuth EKU. The recipient installs
the profile and enables full trust in Certificate Trust Settings. Remove that
trust profile when it is no longer needed. The URL contains an unpredictable
session token; unknown routes cannot expose library or signing files. The server
binds to the Wi-Fi IPv4 address, supports TLS 1.2+, bounded headers, GET/HEAD and
single byte ranges, and streams the selected immutable copy in bounded chunks.

Host and embedded extension profiles must be present and unexpired, and their
entitlements are checked before serving. Sharing preserves the IPA bytes and
signature: it does not create device authorization. The target device still needs
to be covered by its Apple profiles and the selected OTA distribution method.
The HTTPS trust certificate is unrelated to the Apple signing certificate.

A green check confirms **transfer**, not successful installation. iOS's
itms-services installer does not supply this local server with an authenticated
installation-completion callback. The recipient confirms the actual installation.
See [Apple's wireless distribution requirements](https://support.apple.com/guide/deployment/depce7cefc4d/web).

## Validation

- Transport lifecycle, App Group and Core Data context tests passed.
- Settings storyboard, target/profile configuration and bootstrap IPA integrity
  checks passed.
- New protocol/crypto tests pass Apple's TLS trust evaluation and reject a wrong
  destination IP. Trust-profile export contains no private key.
- An actual local Network.framework TLS listener was tested using Python's strict
  OpenSSL verification: token isolation, HTML and manifest, range/HEAD requests,
  complete 4 MiB streaming and listener shutdown all passed.
- Release device build and IPA packaging are checked separately.

Physical iPhone/iPad recipient installation, certificate-profile trust prompts,
UI navigation and cellular-only transport still require hardware acceptance.
These checks do not establish universal compatibility with arbitrary IPAs or
Apple-restricted capabilities.
