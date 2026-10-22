# Native app launch in 0.7.70

My Apps previously delivered the generated `zloader-<bundle-id>://` URL (or a
legacy app's first declared scheme) to the target. Unknown deep links can trigger
browser handling inside an app. The reported app/Safari switch has not been
correlated with the target app's URL-handler logs, so that mechanism is a possible
cause rather than a proven runtime trace.

Normal and context-menu Open now request a native workspace launch of the exact
re-signed bundle identifier, with an empty launch configuration and no URL
payload. The workspace interface is already used by the backup helper. When the
modern interface is absent, the launcher may use the bundle-ID-only legacy
interface. A failed modern launch is not retried through another launch path.
Unavailable APIs and invalid identifiers report an error without opening a URL.
Backup/restore deep links and signing-time scheme registration are retained for
the workflows that intentionally need them.

Automatic-JIT launch already starts/resumes the target through the device gateway.
Its success callback no longer opens the app a second time through a URL scheme.

The Foundation/runtime regression harness uses isolated fake workspace classes;
it cannot launch real apps. It verifies modern success/failure, one legacy
launch, unavailable APIs, invalid identifiers, exact bundle targeting and absence
of payload injection. Release compilation checks the real host bridge. Actual
iPhone launching and JIT foreground behavior still need physical validation.
An application can independently open a browser for login or other own behavior.
