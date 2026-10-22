import Foundation

/// Local copies cannot establish that a profile still exists on Apple's portal.
/// Every resolution starts with a fresh inventory and downloads its candidates.
enum PortalProfileResolver {
    struct Candidate {
        let identifier: String
        let mayRenew: Bool
    }

    static func resolve<Profile>(
        renewExisting: Bool = false,
        list: () async throws -> [Candidate],
        download: (String) async throws -> Profile,
        compatible: (Profile) -> Bool,
        renewable: (Profile) -> Bool,
        renew: (String) async throws -> Profile,
        create: () async throws -> Profile
    ) async throws -> Profile {
        let candidates = try await list()
        var renewalID: String?
        var downloadError: Error?
        for candidate in candidates {
            let profile: Profile
            do {
                profile = try await download(candidate.identifier)
            } catch {
                downloadError = error
                continue
            }
            if compatible(profile), !renewExisting { return profile }
            if renewalID == nil, candidate.mayRenew, renewable(profile) { renewalID = candidate.identifier }
        }
        // A failed read does not prove absence. Do not create duplicates or
        // renew a different profile when portal state could not be established.
        if let downloadError { throw downloadError }
        if let renewalID { return try await renew(renewalID) }
        return try await create()
    }
}
