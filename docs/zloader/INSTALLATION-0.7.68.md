# Installation presentation and self-update in 0.7.68

The running zLoader record is pinned first in the installed-app launcher. Other
apps retain their expiry-based ordering. This is a presentation mapping only:
refresh-all still refreshes the host last, and pending installation tiles remain
after installed apps. Icon refresh uses the same mapped position.

Normal installations no longer automatically open the installed application.
The corresponding automatic-launch preference is removed. This eliminates that
intentional foreground switch; it does not establish that every reported exit
was caused by this preference. Device crash/lifecycle testing remains necessary.

Self-replacement is selected only for an exact match between the signed target
bundle identifier and the currently running executable. The existing staged
self-reinstall record is retained. The host exits only after installation_proxy
acknowledges the submitted package (or installation succeeds), never while
signing/transferring or following a rejected request. There is no blind exit timer.

The pinned iDevice source previously invoked its progress callback only for
PercentComplete. Some installation status responses have no percentage, which
can leave the self-update waiting while the device waits for the old process to
close. The tracked patch forwards error-free status responses as progress zero
and checks Error/ErrorDescription before acknowledging. Successful Complete
responses count as complete. Synthetic tests exercise status-only, percentage,
complete, empty and error responses. Actual self-installation is still untested.

`prepare-patched-idevice.sh` rebuilds the same pinned source revision with its
original default crypto features; only the generated destination library slice
is replaced. Rust 1.99.1 and sources are isolated in ignored build directories.
The corresponding-source archive includes the actual patched library source,
its original license, the patch and the rebuilding script. No binary dependency
gitlink or published upstream artifact is changed.
