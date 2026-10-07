# zLoader release delivery

Every approved app update is built, locally committed and delivered through https://zloader.zynthec.com. Increment marketing/build versions so installed clients can detect the update.

Publish one resignable IPA containing the embedded tunnel and recovery payload. Verify its bundle identity, hash, extension layout and version before updating the source. A matching corresponding-source archive is required with distribution; the source-code GitHub repository can remain private. Do not include signing identities, provisioning profiles, pairing records, anisette data or build caches in the archive.

Preserve other source entries and validate the live feed and downloadable IPA after deployment. A local commit does not authorize pushing the private app repository.

Current distribution preference: the IPA remains local. Only Source branding/domain changes are approved for public deployment. Do not upload an app binary until the separate corresponding-source download is authorized.
