# Capability requests — 0.7.41

App ID details includes localized Capability Requests actions. Request Capability Access opens the exact App ID's Apple Developer Portal page; the explanatory footer directs the Account Holder to the Capability Requests tab for Request/Status. The official Apple guide is also available. Apple login and request submission happen on Apple's website, not via an invented API or a simulated in-app approval state. Pending requests do not block ordinary capability-reduced signing. After approval the user can enable the capability and re-sign to get updated profiles.

Release build and existing regression/IPA checks validate packaging. Actual Apple account login, request eligibility, submission, approval and device navigation remain unverified.
