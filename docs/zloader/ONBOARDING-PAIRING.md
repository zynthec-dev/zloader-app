# Settings and onboarding pairing (0.7.2)

Wireless pairing is available from the pairing step during onboarding on iOS 26+.
The client target picker starts immediately: select a discovered remote device or
use the configured endpoint (the local tunnel peer by default). Enter the PIN
provided by the target when requested. The generated RemotePairing record is
validated/imported and selected as the preferred protocol before onboarding
marks pairing complete. Importing an existing record remains available.

For a configured local endpoint, the existing transport coordinator starts the
embedded tunnel before the handshake and retains its lease until the pairing
callback finishes. Cancel requests stop the pairing service; a synchronous native
FFI call may take until its own return to finish cancellation. The tunnel remains
leased during that interval. No fixed-duration tunnel shutdown timer is added.
Remote LAN discovery targets do not acquire a local transport lease.

Settings has a direct Pairing button and a SwiftUI navigation container, so the
wireless tool and pairing-file detail navigation can be reached after onboarding.
Both Settings storyboards contained six dangling outlet destinations. These were
removed, along with stale social-footer outlets/actions. The version footer is
constructed programmatically. A regression script checks resource destinations,
controller outlets/actions and the module in both storyboards.

The wiring defects were verified in source; the exact reported immediate Settings
crash on iOS 27.0.1 has not been reproduced without a device crash report. A
successful build does not establish that the physical crash is resolved.

## Physical-device acceptance still required

- Update the existing installation without deleting its data, then open Settings
  and its Pairing button on iOS 27.0.1.
- On a fresh onboarding state, start wireless pairing, approve VPN consent and
  complete a real same-device RemotePairing handshake using the configured local
  endpoint. Confirm the generated record is active, persists across relaunch and
  enables CoreDevice operations. Bonjour support alone does not prove same-device
  pairing is accepted by iOS.
- Test wrong PIN, rejected consent, missing Network Extension authorization,
  cancellation before startup/during PIN entry/during native handshake, retries
  and overlapping refresh operations. Inspect the final signed IPA as described
  in [ILOADER.md](ILOADER.md).

The iLoader-signed host/provider must have Apple-authorized Network Extension
entitlements and matching profiles. The IPA declarations alone cannot grant this.
No pairing protocol, entitlement check or Apple signing restriction is bypassed.

## Confirmed Settings initialization crash: 0.7.3

The supplied Xcode screenshot shows `Unexpectedly found nil while implicitly
unwrapping an Optional value` in `heightForHeaderInSection`, passing
`prototypeHeaderFooterView` to `preferredHeight`. In 0.7.2, assigning the version
footer precedes creation of that implicitly unwrapped prototype. Table setup can
reenter the section-height delegate while the prototype is still nil. The earlier
resource-wiring fixes did not address this initialization path.

0.7.3 constructs a nonoptional measurement header when the controller is created.
Settings registers the programmatic header class before configuring its footer.
The header initializer builds all labels, button, stack and constraints; dequeue
uses a typed cast with a fully initialized fallback. Existing XIB compatibility
is retained for the view class. Both header and footer measurements therefore
use an initialized view independent of the controller's view-loading order.

Restart the paused Xcode run with the new code, open Settings both signed out
and signed in, scroll all sections, and verify the Pairing button. This runtime
check on the reported iPhone remains outstanding; the screenshot identifies the
fault but is not evidence that the updated binary has run successfully.
