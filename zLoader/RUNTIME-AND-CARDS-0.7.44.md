# Runtime and cards, 0.7.44

## Self replacement

The previous implementation suspended the host before the synchronous install call. That leaves its process alive. The new Idevice gateway submits the already-transferred package and waits for a positive installation_proxy progress callback before requesting process termination on the main queue. There is no exit timer and no early termination before a service response. Staged installation metadata is written atomically; launch reconciliation still requires the installed version/build and changed bundle path. No successful update is fabricated from progress alone.

This pathway uses the Idevice backend. Other backends report an explicit unsupported-operation error rather than ending the app before submission. The ongoing integrated Network Extension is a separate process. Do not stop transport before acknowledgement. The first progress response confirms acceptance, not final validation: subsequent device-side installation failures can still occur after the host exits. Physical iPhone acceptance must verify replacement, reopening and database preservation. The old installed updater cannot acquire this fix before installing this version externally once.

## JIT launch

The per-app automatic preference is under JIT Settings; changing it never launches the app. Open with JIT appears immediately below Open. Automatic opening uses the same path. With remote pairing, CoreDevice launches the app stopped, the debugger attaches to the returned PID and detaches before the UI is foregrounded. An existing target process is relaunched by CoreDevice. If attachment fails, SIGCONT releases the stopped process and the caller receives the error. Legacy Lockdown uses debugserver launch. Activation without launching attaches only to a running process, including legacy pairing. Removed three identical unconditional retries and a redundant nested transport readiness check. SideJITServer activation of running apps remains available; pre-launch JIT uses the local Idevice backend and requires valid pairing and a developer image.

This does not introduce an unrestricted background daemon or automatic detection of other apps launching. Shortcuts keep their background activation intent. Actual launch order/JIT execution must be checked on a paired iPhone with a JIT-dependent app.

## Presentation

Shared SwiftUI list surfaces and UIKit Settings rows use native iOS 26 regular glass cards; Reduce Transparency and older OS versions use opaque semantic grouped surfaces. A fixed, subtle light/dark texture gives glass a background, without restoring user wallpaper settings. Settings rows retain their controls, navigation and accessible labels. Sources, app banners and news cards share neutral glass surfaces. My Apps uses responsive launcher cards, direct tap-to-open, long-press management and existing circular operation progress. Accessibility text sizes use a single column. Visual review on hardware remains required, particularly large text, light/dark and Reduce Transparency.

## Validation

Run the three required local scripts, build-unsigned.sh and test-bootstrap-package.py. Dependency changes are carried in the tracked minimuxer patch; pinned gitlinks are unchanged.
