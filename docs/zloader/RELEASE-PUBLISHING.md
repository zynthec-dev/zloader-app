# zLoader release delivery

Every approved app update is built, locally committed and delivered through https://source.zloader.de. Use this source for all future zLoader updates. Increment marketing/build versions so installed clients can detect the update.

Existing installs migrate the former fixed source URLs (including `https://zynthec.com/zloader/source.json`) to `https://source.zloader.de` on startup while retaining app and news relationships. Keep the old public endpoint redirecting to the new source so older installed builds can discover the migration release.

Publish one resignable IPA containing the host and widget, using the external WireGuard tunnel as documented in README. Verify its bundle identity, hash, extension layout and version before updating the source. A matching corresponding-source archive is required with distribution; the source-code GitHub repository can remain private. Do not include signing identities, provisioning profiles, pairing records, anisette data or build caches in the archive.

Preserve other source entries and validate the live feed and downloadable IPA after deployment. A local commit does not authorize pushing the private app repository.

The 0.7.56 IPA and its matching corresponding-source archive are approved for public release on source.zloader.de. Publish both together; keep credentials and private repository history local.
