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
    static func incompatibilities(_ profile: EmbeddedProfileSnapshot, for target: ProfileReuseRequirements, now: Date = Date()) -> [String] {
        var failures: [String] = []
        if profile.bundleID != target.bundleID { failures.append("app ID mismatch (returned " + profile.bundleID + ")") }
        if profile.teamID != target.teamID { failures.append("developer team mismatch") }
        if profile.expiresAt <= now { failures.append("profile expired") }
        if target.certificate.isEmpty || !profile.certificates.contains(target.certificate) { failures.append("selected signing certificate is not authorized") }
        if target.deviceID.isEmpty || !profile.devices.contains(where: { $0.caseInsensitiveCompare(target.deviceID) == .orderedSame }) { failures.append("current device is not authorized") }
        for key in [PacketTunnelProvisioning.entitlement, "com.apple.security.application-groups"] {
            guard let required = target.entitlements[key] as? [String] else { continue }
            let authorized = profile.entitlements[key] as? [String] ?? []
            let missing = required.filter { !authorized.contains($0) }
            if !missing.isEmpty { failures.append("missing " + key + ": " + missing.joined(separator: ", ")) }
        }
        return failures
    }

    static func accepts(_ profile: EmbeddedProfileSnapshot, for target: ProfileReuseRequirements, now: Date = Date()) -> Bool {
        incompatibilities(profile, for: target, now: now).isEmpty
    }
}
