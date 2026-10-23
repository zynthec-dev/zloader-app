# Container integration in 0.8.1

The settings entry is **Container-Einstellungen** under Advanced Settings. The
embedded settings omit source management, manual certificate import/removal/export,
identity transfer, global JIT providers and the 32-bit emulator picker. JIT-less
diagnostics, device identity, tweaks and the remaining settings stay available.
User-facing runtime localization uses Container; original project names, URLs,
author credits, code identifiers and licenses remain intact.

Before each container signing operation, the host supplies its active imported or
Apple-account signing certificate to the isolated signing vault. The certificate
must be unexpired and authorized by the installed host's unexpired provisioning
profile. A changed certificate refreshes the vault; invalid/missing identities
clear stale material. The identity must also have its private key available to
zLoader. Apple login, provisioning and the IPA library are otherwise unchanged.

**Mit JIT starten** in the container's long-press menu launches a LiveProcess window
and attaches zLoader's existing integrated debugger backend to that process's PID.
It does not attach to a foreground host which would lose JIT on relaunch. The
child waits at most 30 seconds before entering the guest, and reports failure
rather than waiting indefinitely. The host's old external-provider and debugger
wait preferences do not control this integrated path. iOS and transport support,
pairing and valid signing material remain necessary; this is not an entitlement
or certificate-authorization bypass.

Virtual windows now share one actual host view/controller owner. Previously the
dock view was inserted under the tab controller but the child was registered
under the launch controller; UIKit raised UIViewControllerHierarchyInconsistency.
The active normal key window is selected explicitly. Bookmark creation/resolution
and extension/PID failures are checked, startup callbacks are installed before
launch, and delegate ownership avoids retaining the window through a cycle.

Browser redirects remain inside the running guest. Guest-image scene delegates and the guest’s declared platform Scene lifecycle
receive scene URL callbacks; a leftover host scene cannot swallow a
legacy AppDelegate callback. Safari-wrapper callbacks are delivered before the
browser disappears so wrapper cancellation cannot invalidate pending OAuth state.
Native ASWebAuthenticationSession subclasses retain Apple's implementation.
Platform SwiftUI Scene delegates remain supported for Scene-based guests.
The startup fade exposes its tab controls to accessibility after interaction is
available, preventing an early ignored tab selection. Container Settings uses
an inline navigation title to avoid reserving a second large title area.

## Validation and limits

The original crash was reproduced in the dedicated iOS 27 Simulator. The first
seven UI tests passed after the fix, including virtual-window launch, WKWebView,
public Safari, Safari wrapper, both ASWebAuthenticationSession initializers,
legacy AppDelegate callbacks and isolation from an installed scheme-collision app.
Extended runs additionally exercise resizing, minimizing and launching another
guest while the first one remains alive. The startup transition test waits for
interactive tabs rather than treating the intentional accessibility fade as
onboarding. The release receipt records the final per-test results.
All 28 local regression scripts passed, including the already committed Watch
bundle signing change. Device Release packaging and the final UI run are separate
required release checks.

The supplied DHL 10.1 IPA was inspected locally only. It declares `dhllogin` and
`dhllogout`, has no Scene manifest and includes a UIViewController Safari wrapper.
No DHL account, password or real token was used. The device IPA cannot execute as
a Simulator app. A real DHL sign-in and physical-device LiveProcess/JIT/PiP,
Apple-portal/profile renewal, Watch installation and self-update still need device
validation. Synthetic OAuth tests establish callback routing and ordering, not
provider-side acceptance. The DHL IPA and its extracted binary are excluded from
the distributed app and corresponding-source archive.
