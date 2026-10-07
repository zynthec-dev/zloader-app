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
        // These values are generated for the selected identity by the signer.
        // Application identity, team and device are checked separately above.
        let generated: Set<String> = ["application-identifier", "com.apple.developer.team-identifier", "get-task-allow"]
        for key in target.entitlements.keys.sorted() where !generated.contains(key) {
            guard let required = target.entitlements[key] else { continue }
            if let flag = required as? Bool, !flag { continue }
            if let values = required as? [Any], values.isEmpty { continue }
            let value: Any
            if key == "keychain-access-groups", let groups = required as? [String] {
                value = groups.map { group in
                    guard let dot = group.firstIndex(of: ".") else { return group }
                    return target.teamID + group[dot...]
                }
            } else {
                value = required
            }
            if !authorizes(profile.entitlements[key], requested: value) {
                failures.append("missing or incompatible entitlement " + key)
            }
        }
        return failures
    }

    private static func authorizes(_ allowed: Any?, requested: Any) -> Bool {
        if let values = requested as? [Any] {
            guard let rules = allowed as? [Any] else { return false }
            return values.allSatisfy { value in rules.contains { authorizes($0, requested: value) } }
        }
        if let value = requested as? String, let rule = allowed as? String {
            // Only Apple's returned allow-list may contain a granting wildcard.
            let pattern = "^" + NSRegularExpression.escapedPattern(for: rule).replacingOccurrences(of: "\\*", with: ".*") + "$"
            return value.range(of: pattern, options: .regularExpression) != nil
        }
        guard let allowed else { return false }
        return (requested as? NSObject)?.isEqual(allowed) == true
    }

    static func accepts(_ profile: EmbeddedProfileSnapshot, for target: ProfileReuseRequirements,
                        requiredDevices: Set<String>, now: Date = Date()) -> Bool {
        accepts(profile, for: target, now: now) &&
            Set(requiredDevices.map { $0.lowercased() }).isSubset(of: Set(profile.devices.map { $0.lowercased() }))
    }

    static func accepts(_ profile: EmbeddedProfileSnapshot, for target: ProfileReuseRequirements, now: Date = Date()) -> Bool {
        incompatibilities(profile, for: target, now: now).isEmpty
    }
}

/// Names identify only candidates; downloaded bundle/team and newly issued
/// profile authorization must still be validated before signing.
enum ManagedProfileNaming {
    static func isOwned(_ name: String, base: String) -> Bool {
        name == base || (name.hasPrefix(base + " [") && name.hasSuffix("]"))
    }

    static func uniqueName(base: String, identity: String) -> String {
        base + " [" + identity + "]"
    }
}
