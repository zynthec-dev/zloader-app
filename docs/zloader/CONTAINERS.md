# Embedded containers

zLoader embeds LiveContainer 3.8.11 from revision
`9108ae624ea001f7d7696d48407f890b48fa2653`. Original authors, AGPL-3.0,
ZSign/Feather, litehook and dependency notices remain in the vendored sources,
About and the distributed corresponding-source archive. `Vendor/LiveContainer/UPSTREAM.json`
records the original per-file hashes and dependency pins. Local changes are
distributed with the same source, not as an opaque prebuilt guest runtime.

## Navigation and installation

My Apps has adjacent Installed Apps and Container Apps pages, reachable by swipe
or segment selection. Existing device installation, Apple login, imported signing
identities and the private refresh cache retain their own pipelines. The Plus
picker offers device installation or importing the IPA into LiveContainer.
Container apps do not occupy separate Home Screen app-install slots. They use
the host runtime; app compatibility is subject to the original loader's limits.

The original app/data-container management, app settings, imports, tweaks, JIT
settings, multitasking, PiP, sources and diagnostic views are embedded. General
Container settings live in zLoader Settings. The host retains its own navigation,
default source and device signing. Do not substitute LiveContainer's original
SideStore host hooks for zLoader's host controller.

The Home Screen shortcut action generates a removable web-clip configuration with
zLoader's URL scheme, exact guest bundle folder, selected data-container folder
and icon. A temporary loopback-only page serves the profile with Apple's MIME
type; the listener stops when that sheet closes. Different data containers have
different stable profile identifiers so their shortcuts can coexist. iOS requires
the user to confirm the download and install the profile in Settings; generating
one does not mean that a Home Screen shortcut has already been installed. See
[Apple's profile-installation instructions](https://support.apple.com/en-gb/102400).

## Identity and browser callbacks

Host identity is the default. Optional virtual mode shares one persisted identity
across every guest: iPhone 16 Pro Max / iPhone17,2, synthetic serial/device IDs,
device name and IDFV. Regeneration replaces the shared values for the next guest
launch and retains app data. Already running guests retain their launch snapshot.
Supported UIDevice, sysctl, uname and available MobileGestalt/IOKit queries are
adapted. This does not alter hardware, Apple profiles, attestation, permissions,
OS version or advertising identity; an app may perform other checks.

Owned custom URL schemes from guest metadata and active authentication sessions
are delivered to the running guest directly. WKWebView delegates are proxied,
including web views without a delegate. SFSafariViewController windows use an
in-process browser to prevent their remote Safari process from dispatching the
callback to a separately installed app. Native ASWebAuthenticationSession keeps
its system authentication UI and wraps callback completion once. Some identity
providers refuse embedded WebKit or depend on Safari cookies; provider-specific
compatibility needs a real login test. Callback credentials are not logged.

## Signing and boundaries

Container execution needs compatible host signing/JIT-less setup or supported
JIT. Container Settings can copy an imported/active signing identity only when its
certificate also signs the installed host and has not expired. The P12 and random
password pass in memory into a separate Keychain vault; they are never published
or stored in UserDefaults. The vault's access group is separate from the 128
groups allocated to guest data containers. Guest code still executes inside the
host's process/permissions; this is not a security boundary for untrusted code.

The resignable package includes the host, widget and three LiveContainer
extensions with their capability requests. Apple must grant the actual App Group
and Keychain entitlements when re-signing every retained target. Free-account
app/extension limits still apply. No profile or ad-hoc entitlement metadata grants
an Apple capability, extends expiry or makes the package directly installable.

## Build and acceptance

The canonical `build-unsigned.sh` builds and embeds the runtime automatically.
`prepare-livecontainer.sh` fetches the pinned OpenSSL distribution into ignored
build storage. Simulator and device builds must be serialized because the host's
backup packaging shares an output path. Simulator uses Xcode's regular ad-hoc
Simulator signing; do not attach device-only entitlements to its macOS signature.

`test-containers.sh` checks URL ownership, shared identity persistence/regeneration
and isolated ZIP extraction, including escaping paths and links. Synthetic native
Simulator fixture IPAs are built by `prepare-container-fixtures.sh`. The fixture
server binds only 127.0.0.1:18769, uses no account and returns synthetic callbacks.
The `zLoader-ContainerTests` scheme exercises the actual UIKit/SwiftUI app with
German labels. Copy Alpha.ipa/Beta.ipa into the dedicated test installation's
Documents directory and install NativeCollision.app before running the suite.
Use a dedicated Simulator, not one occupied by another project's UI tests. The
repeatable `ZLOADER_SIMULATOR_ID=... sh zLoader/scripts/test-container-ui.sh` harness
builds the app, installs/copies only the synthetic fixtures, starts the local
server and runs the suite with an xcresult bundle. It replaces prior Alpha/Beta
fixture app bundles only. Simulator guest patching renews the local ad-hoc Mach-O
seal; the device path still requires Apple's real signing or supported JIT.

Release 0.8.0 acceptance on 22 October 2026 passed all four UI tests on the
dedicated iOS 27.0 Simulator: onboarding without an Apple account; segment/swipe
navigation and settings; both synthetic IPA imports; automatic guest launch;
shared virtual IDFV and iPhone17,2 machine reports; WKWebView, public Safari,
legacy ASWebAuthenticationSession and modern Callback return handling while a
native app owns the same scheme; shared-identity regeneration with persistent
guest app data; returning to host identity; shortcut menu and loopback landing
page. The harness separately verified the copied URL's guest and data-container
identity. The four-test suite completed successfully with an xcresult bundle.
The documented 28 local regression scripts passed, with the expanded shortcut
server/profile checks repeated after the latest changes.

Simulator cannot validate Apple's portal, certificate/profile renewal, real
installation_proxy transport, Home Screen profile installation, CarPlay, actual
JIT-less signatures or real self replacement. Physical iPhone acceptance remains
required for those operations, cellular-only transport, real OAuth providers and
LiveProcess/PiP system integration. A compiled runtime or passing UI test must not
be presented as proof that every third-party IPA works on a physical device.
