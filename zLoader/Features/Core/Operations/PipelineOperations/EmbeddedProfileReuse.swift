import Foundation

struct EmbeddedProfileSnapshot {
    let bundleID: String
    let teamID: String
    let expiresAt: Date
    let certificates: [Data]
    let devices: [String]
    let entitlements: [String: Any]
}

struct ProfileReuseRequirements {
    let bundleID: String
    let teamID: String
    let certificate: Data
    let deviceID: String
    let entitlements: [String: Any]
}

enum EmbeddedProfileReuse {
    static func accepts(_ profile: EmbeddedProfileSnapshot, for target: ProfileReuseRequirements, now: Date = Date()) -> Bool {
        guard profile.bundleID == target.bundleID,
              profile.teamID == target.teamID,
              profile.expiresAt > now,
              !target.certificate.isEmpty,
              profile.certificates.contains(target.certificate),
              !target.deviceID.isEmpty,
              profile.devices.contains(where: { $0.caseInsensitiveCompare(target.deviceID) == .orderedSame }) else {
            return false
        }
        for key in [PacketTunnelProvisioning.entitlement, "com.apple.security.application-groups"] {
            guard let required = target.entitlements[key] as? [String] else { continue }
            let authorized = profile.entitlements[key] as? [String] ?? []
            guard required.allSatisfy({ authorized.contains($0) }) else { return false }
        }
        return true
    }
}
