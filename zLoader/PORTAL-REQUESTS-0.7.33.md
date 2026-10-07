# Developer Portal request correction — 0.7.33

Reported device failure: signing, refresh and App ID edits return SideSign.ServerError 3 / Apple result 4006 (Bad Request). The screenshot does not identify the failing endpoint, so it does not establish a definitive cause or an authentication failure.

Capability updates now fetch Apple's current App ID and submit only changed service values. Unchanged values, including unknown legacy services returned by Apple's list API, are not echoed into a mutation. Explicit disabling remains supported; identical requests are no-ops. The request also includes the entitlements dictionary used by the original AltSign updateAppId API. No certificate, identifier or profile is removed by this correction.

Unmapped Apple result errors now include the endpoint (and JSON API method). Tokens, headers, request bodies and account identifiers are not added to the user-facing error. This distinguishes e.g. updateAppId.action from profile creation, group assignment or team lookup on the next failure.

Validation: capability delta tests exercise enabling, disabling, unchanged values, missing false flags, whitespace/case normalization and unknown unchanged values. Transport, App Group, context and Settings storyboard tests are run along with the Release build and bootstrap package audit. These checks do not verify Apple's live mutation acceptance or the user's device.

Device acceptance required: edit and save one capability; sign a third-party IPA; refresh zLoader. If result 4006 remains, retain the endpoint now included in Error Log. Do not reset anisette data, revoke certificates, delete App IDs or reinstall speculatively: this error alone does not justify destructive recovery.
