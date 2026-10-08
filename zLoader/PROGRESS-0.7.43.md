# Determinate progress only — 0.7.43

Refresh/install progress no longer starts the rotating UIButton activity indicator, including custom-style buttons. Refresh All binds its circular indicator to the actual RefreshGroup progress and clears it on completion. The install toolbar action is temporarily disabled rather than replaced with a spinner. Loading icons and unrelated indeterminate activities retain their own loading indicators. The accent-color progress circles and percentages are unchanged.

Release build, transport, App Groups, context and bootstrap IPA integrity checks cover compilation and packaging. UI rendering and physical self-update remain device acceptance tasks.
