# Entitlement requests and profile authority — 0.7.36

Reported LiveContainer installation fails before provisioning with an unconfirmed increasedMemoryLimit service flag. The additional zLoader portal-list confirmation was treating an absent legacy flag as a signing rejection, although the profile had not yet been checked.

Kernel memory options (increased memory, extended virtual addressing and increased debugging memory) now use their actual entitlement keys in the updateAppId request's entitlements dictionary. Ordinary capabilities still use their Developer Services service flags. Request booleans are encoded as plist booleans.

The signing pipeline continues after Apple accepts the App ID mutation, without requiring the legacy feature list to repeat every requested flag. Manual portal editing retains its readback confirmation. Actual mutation failures are not caught or treated as success.

The host and each extension still need an Apple-signed profile authorizing their resolved identity, active certificate, selected devices and required entitlements. Existing compatible profiles are reused. If Apple accepts the request but omits only the three optional kernel memory rights, signing removes those ungranted rights from the final host/extension signature. The omission is logged and recorded in the output IPA Info.plist as ZLoaderOmittedOptionalEntitlements. The app has no increased memory allowance in that case. Critical capabilities are never removed: a tunnel, App Group, device, certificate or other required mismatch still fails. No entitlements are forged.

Validation: request serialization regression checks for kernel entitlement keys, true/false values and ordinary capability flags; profile authorization, transport, App Group and context tests; Release build and bootstrap IPA audit. LiveContainer installation on the device remains the acceptance test.
