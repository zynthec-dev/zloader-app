# Self-update handoff correction — 0.7.37

Reported Source self-update leaves zLoader and does not install the update. The old implementation stopped keepalive services and scheduled a detached foreground suspension after 500 ms before entering the installation call (which still has to acquire the transport). That timer was not evidence that iOS had accepted the install request.

Self-install now retains the running operation/transport and keepalive until the actual install call completes or fails. A scoped iOS background task covers this call if the user leaves the foreground. There is no timer-driven suspension or forced process exit. Errors remain visible through the normal installation error path. Failed requests remove staged self-reinstall metadata. Boot reconciliation additionally checks the staged target version/build before applying database updates after an observed bundle path change.

This correction removes a premature handoff; it does not prove the installation completed on a physical iPhone. iOS may terminate the old process when replacing its bundle. If the installation service waits for the foreground app to leave, the user may still need to go to the Home Screen manually. Automatic suspension is intentionally not inferred from elapsed time: the current backend does not expose an accepted-install progress event for all transports.

Acceptance: update 0.7.36 to 0.7.37 via Source; observe transport/request errors if any, and reopen to confirm the actual installed version/build, not just the Source/database version. Test both internal and external tunnel methods. A source IPA update cannot repair code already executing in the old version; the first installation of this correction may require an external sideloading tool.
