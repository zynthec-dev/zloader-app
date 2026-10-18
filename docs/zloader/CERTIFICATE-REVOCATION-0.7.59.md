# Certificate revocation HTTP 421 handling in 0.7.59

The device reported `Request failed HTTP 421 Developer Portal` when revoking a
certificate. The paid-team certificate flow uses Apple's web-portal endpoint
with an Xcode token; that route can reject the request before revocation is
confirmed. A status alone does not establish why Apple's server rejected it.

The tracked SideSign managed-signing patch now handles only HTTP 421 from that
web-portal certificate route by switching to the existing Xcode certificate
service at `developerservices2.apple.com/services/v1/certificates`.

- A rejected inventory read may be repeated once through the Xcode service.
- After a rejected web DELETE, the selected certificate is resolved again on
  the Xcode service by serial number AND DER certificate bytes. The service's
  own resource ID is used; web resource IDs are never reused across APIs.
- Revocation is checked by a fresh inventory read from the service that
  accepted the DELETE. An unconfirmed result remains an error.
- Other HTTP errors, network failures, ambiguous results and repeated Xcode
  rejections do not trigger another destructive request. Local keys and active
  certificate selection are retained on failure.

The original API routes and attribution are retained from SideSign:
https://github.com/SideStore/SideSign/blob/main/Sources/DeveloperPortal/Certificates.swift

`test-certificate-revocation.sh` compiles the actual production certificate
control flow against an isolated transport/model fixture. Only external import
and access-level declarations are adjusted for this standalone harness. It
covers normal and free-team revocation, HTTP 421 during reads and DELETE,
service-local IDs, mismatched DER rejection, bounded retries, other HTTP errors
and failed post-revocation confirmation. No Apple account or real revocation is
used in testing. Physical-device validation is still required.

Version/build: 0.7.59 / 0759. The working Apple-login changes from 0.7.58 remain.
