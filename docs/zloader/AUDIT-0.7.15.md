# zLoader 0.7.15 validation and remaining work

This is an independently maintained SideStore fork. SideStore endorsement is not
claimed. Original authors and licenses remain credited. Only Release remains in
the Xcode project, with the canonical host ID `com.zynthec.zLoader` and separate
Widget, Tunnel and Backup IDs. The former audit's duplicate-suffix configuration
is historical; it does not describe today's local Release configuration. Moving
an existing installation to these IDs can change its data containers.

## Implemented in this working tree

- Exact Apple Development versus iOS Development certificate request types.
- Explicit Portal certificate download; local imported/created/active identities
  are separated from the remote list. A remote certificate has a private key
  only when a matching local key is already available. Confirmed remote revoke
  resolves the Portal resource ID and verifies disappearance before local removal.
- Host and each extension use separate validated profiles. Reuse requires the
  same team, certificate, device, app identity, expiry and requested entitlements.
  Signing preserves literal requested entitlement values and rejects permissions
  Apple did not grant. No profile fallback from another target.
- Native list entitlement editing, including preservation of noneditable complex
  values and the drafts of unselected extensions. No default extra memory rights
  injected into unrelated apps.
- Editable supported App-ID features and a profile export/import package holding
  individual Apple-signed profiles; it does not merge Apple's signatures.
- Prominent tunnel setup button, Continue after configuration save/reload.
- [Optional Xcode hosts over SSH](XCODE-SSH-HOSTS.md), password or Ed25519 key,
  fingerprint approval, project discovery, Release archive/export and unchanged
  IPA installation. Installed projects use that host for subsequent refresh.

## Validation

Local transport, App Group, context confinement, packet tunnel provisioning,
embedded profile reuse, pairing import, Settings storyboard and project layout
checks passed. Certificate tests verified password-protected PKCS12 import with
Apple and the pinned CodeSignKit, Unicode passwords, matching private keys,
wrong-password rejection and local CSR signatures. Managed signing checks verify
exact certificate type names, literal entitlement values, identity remapping and
rejection of unauthorized rights. Python host tests check confined paths and
Xcode arguments with subprocess mocks. Real loopback SSH tests verify both
supported auth methods and rejection of unknown/changed host keys.

A successful iOS Release build is a compile/package check. Apple signature/profile
verification is a separate artifact check. Neither establishes physical runtime.

## Remaining limits and work

- Cellular-only refresh still needs a physical iPhone test. The Wi-Fi-only
  readiness guard and concurrent initialization were corrected. Changing the
  local interface subnet is a hypothesis for peer reachability, not a confirmed
  hardware fix. Capture a device log with Wi-Fi off before claiming success.
- New certificate/capability creation and revoke requests have not been exercised
  against the live Apple account. API format validation and compilation cannot
  prove that the current Developer Services endpoint grants these requests.
- SSH end-to-end Mac archive/export, SFTP transfer, iPhone installation and
  refresh are untested. RSA/agents/interactive authentication are unsupported.
- Full native Developer Portal parity, including iCloud container management and
  container association, has not been implemented. Enabling a feature flag alone
  is not a substitute for those associations or Apple's restricted approvals.
- Fresh SSH dependency compiles still produce concurrency/deprecation warnings.
  They are not suppressed; an incremental clean log does not resolve them.
- Light/Dark appearance, onboarding consent and device lifecycle need a visual
  device pass. No claim of a complete, gap-free code audit is made.
- Existing signing tools can rewrite identities or remove capabilities. Only an
  installer preserving the fully authorized signed export can retain them;
  zLoader cannot grant permissions missing from an installed Apple profile.

No private key was exported from the Mac to make the signed release. Portal
certificates and registered devices were not deleted or changed by this work.
