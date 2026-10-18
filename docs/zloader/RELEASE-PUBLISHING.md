# zLoader release delivery

Every approved app update is built, locally committed and delivered through https://source.zloader.de. Use this source for all future zLoader updates. Increment marketing/build versions so installed clients can detect the update.

Existing installs migrate the former fixed source URLs (including `https://zynthec.com/zloader/source.json`) to `https://source.zloader.de` on startup while retaining app and news relationships. Keep the old public endpoint redirecting to the new source so older installed builds can discover the migration release.

Publish one resignable IPA containing the host and widget, using the external WireGuard tunnel as documented in README. Verify its bundle identity, hash, extension layout and version before updating the source. A matching corresponding-source archive is required with distribution; the source-code GitHub repository can remain private. Do not include signing identities, provisioning profiles, pairing records, anisette data or build caches in the archive.

Preserve other source entries and validate the live feed and downloadable IPA after deployment. A local commit does not authorize pushing the private app repository.

Standing user authorization: publish every new zLoader version directly after the required build and local checks pass. This includes 0.7.57 and future updates. Publish the resignable IPA and matching corresponding-source archive as separate public GitHub release downloads in `zynthec-dev/zloader-altsource`, then update source.zloader.de. The feed contains only the app update and IPA download; the source archive is available separately from the release. Keep credentials and private repository history local. Physical-device validation is a separate claim and must be described accurately.
