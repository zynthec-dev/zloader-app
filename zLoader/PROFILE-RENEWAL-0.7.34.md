# Profile renewal and capability confirmation — 0.7.34

Device report: Apple createProvisioningProfile.action returns result 35, "Multiple profiles found with the name". Separate LiveContainer installation fails with PortalMutationError.updateNotConfirmed.

Paid-team managed signing now downloads and selects one zLoader-owned profile, verifies its actual bundle and team, and regenerates it by provisioningProfileId. The regenerated name contains its full portal identifier, so duplicate historical names no longer collide. First creation also uses a unique suffix. Host and each extension still use separate profile requests with certificate and selected devices; all returned profile authorization checks remain enforced. Existing profiles are no longer deleted as part of refresh. Historical duplicates and unrelated Xcode profiles are retained.

App ID confirmation compares only requested capability deltas with refreshed Apple state, with up to three readbacks, instead of comparing the entire old dictionary. Failure lists the unconfirmed service identifiers; acceptance is not invented or inferred from local state.

Validation: profile naming/ownership boundary regression checks; profile authorization suite; mixed capability/delta suite; transport, App Group and context suites; Release build and bootstrap IPA audit. Real Apple profile regeneration, LiveContainer signing and physical refresh are not established by these local checks and must be retried on the device.
