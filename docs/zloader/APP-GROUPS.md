# App Group startup and re-signing

The reported device shows “App Group Container Inaccessible” before onboarding.
The user confirmed a standalone Home Screen installation, installed/signed with
SideStore and LiveContainer and a paid account. The installed signed IPA and its
profiles have not been inspected, so the exact device cause remains unconfirmed.

## Confirmed packaging issue

`CODE_SIGNING_ALLOWED=NO` leaves the unsigned device executable without a Mach-O
entitlements blob. SideSign's `AppBundle.entitlements` reads that blob through
CodeSignKit's `MachOParser`; the importer cannot infer the requested App Groups
from the source xcconfig or an unattached entitlement plist. A paid account alone
does not restore missing capability requests.

`package-resignable.py` now stages a separate `zLoader-resignable.ipa`, seals its
nested executable bundles with local ad-hoc signatures, then the host, and checks
the exact XML entitlement slot read by SideSign. Requests are:

| Bundle | Capability request |
| --- | --- |
| zLoader | `group.com.zynthec.zLoader`, `packet-tunnel-provider` |
| zLoaderWidget | `group.com.zynthec.zLoader` |
| zLoaderTunnel | `packet-tunnel-provider` |

This expresses requirements only. It grants no App Group or Network Extension
authorization and does not make the IPA directly installable. The signer must
register the group and enable it for the host and widget App IDs, obtain matching
Apple profiles, and separately provision Network Extension for host/provider.
The final signed entitlements must match the profiles. See Apple's
[App Group configuration](https://developer.apple.com/documentation/xcode/configuring-app-groups).

## Runtime selection

The runtime checks declared groups against iOS's container API. Exact preferred
group and recognized team suffixes take priority. A single renamed declared group
is accepted only when accessible. Ambiguous groups and an inaccessible preferred
group fail explicitly instead of selecting another database. No private sandbox
fallback is created and no existing database is deleted.

The error now distinguishes missing entitlement declarations from an inaccessible
or ambiguous declared group and includes the declared identifiers for diagnosis.
Ten resolver cases test authorized, renamed, denied and ambiguous groups.

## Device follow-up

Import the **resignable** IPA into SideStore and sign it using the paid team, with
extensions retained and App Groups enabled. For an existing installation, preserve
its actual signed bundle ID and App Group identity and install as an update;
changing either can disconnect existing data. Do not delete the existing app as a
repair step. A signer that strips App Groups or Network Extension must be configured
to retain/provision them or replaced with a capability-aware signing workflow.

Device acceptance remains: inspect final host/widget entitlements and profiles,
launch on the iPhone, complete onboarding and confirm shared database/widget access.
Transport/VPN acceptance is a separate check after container access is restored.
