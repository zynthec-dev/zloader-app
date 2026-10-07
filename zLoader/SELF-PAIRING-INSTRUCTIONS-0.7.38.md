# Manual Self-Pairing instructions — 0.7.38

Start Pairing no longer opens a Settings URL. After the local pairing server reports readiness, a native alert explains the Settings path, device passcode / six-digit pairing PIN and how to return after completion. The alert is localized in English and German. Dismissing it keeps the server and existing Live Activity/notification lifecycle running. Remote Wireless Pairing retains its existing flow.

The private App-prefs route and the method/flag for opening Settings are removed from the Self-Pairing model. A failed server start does not display the ready instructions; stopping the session clears the presentation state.

Validation: transport, App Group and context checks; Release build and bootstrap IPA integrity. Physical readiness/alert presentation and pairing completion remain device acceptance checks.
