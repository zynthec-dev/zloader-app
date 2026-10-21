import Foundation

@main
struct ManagedSigningTests {
    static func main() throws {
        precondition(CertificateType.development.portalType == "DEVELOPMENT")
        precondition(CertificateType.iosDevelopment.portalType == "IOS_DEVELOPMENT")
        precondition(CertificateType.distribution.portalType == "DISTRIBUTION")
        precondition(CertificateType.iosDistribution.portalType == "IOS_DISTRIBUTION")
        precondition(CertificateType.developerID.portalType == nil)
        let originalRequests = try PropertyListSerialization.data(fromPropertyList: [
            "com.apple.developer.carplay-audio": true, "com.apple.developer.future": ["value"],
            "application-identifier": "OLD.app"], format: .xml, options: 0)
        let signedRequests = try PropertyListSerialization.data(fromPropertyList: [
            "application-identifier": "TEAM.app", "com.apple.developer.future": false], format: .xml, options: 0)
        let xml = String(data: signedRequests, encoding: .utf8)!
        let mergedXML = EntitlementMetadata.mergedXML(signature: xml, sidecar: originalRequests)
        let merged = try PropertyListSerialization.propertyList(from: Data(mergedXML.utf8), format: nil) as! [String: Any]
        precondition(merged["com.apple.developer.carplay-audio"] as? Bool == true)
        precondition(merged["application-identifier"] as? String == "TEAM.app")
        precondition(merged["com.apple.developer.future"] as? Bool == false)
        precondition(EntitlementMetadata.mergedXML(signature: xml, sidecar: Data([0, 1])) == xml)
        // Regression: human-readable capability keys were ignored by Apple's legacy API.
        precondition(Feature(entitlement: .networkExtensions)?.rawValue == "NWEXT04537")
        precondition(Feature(entitlement: .vpn)?.rawValue == "V66P55NK2I")
        precondition(Feature(entitlement: .associatedDomains)?.rawValue == "SKC3T5S89Y")
        let profile: [String: Any] = ["application-identifier": "TEAM.example.app", "get-task-allow": true,
            "com.apple.developer.associated-domains": ["*"], "keychain-access-groups": ["TEAM.*"],
            "com.apple.security.application-groups": ["group.shared.TEAM", "group.unused.TEAM"],
            "com.apple.developer.networking.networkextension": ["packet-tunnel-provider", "app-proxy-provider"]]
        let requested: [String: Any] = ["application-identifier": "OLD.example.app",
            "com.apple.developer.associated-domains": ["applinks:example.com"], "keychain-access-groups": ["OLD.example.shared"],
            "com.apple.security.application-groups": ["group.shared"],
            "com.apple.developer.networking.networkextension": ["packet-tunnel-provider"]]
        let actual = try SigningEntitlements.prepare(application: requested, profile: profile, teamID: "TEAM")
        precondition(actual["application-identifier"] as? String == "TEAM.example.app")
        precondition(actual["com.apple.developer.associated-domains"] as? [String] == ["applinks:example.com"])
        precondition(actual["keychain-access-groups"] as? [String] == ["TEAM.example.shared"])
        precondition(actual["com.apple.security.application-groups"] as? [String] == ["group.shared.TEAM"])
        precondition(actual["com.apple.developer.networking.networkextension"] as? [String] == ["packet-tunnel-provider"])
        do {
            _ = try SigningEntitlements.prepare(application: ["unauthorized": true], profile: profile, teamID: "TEAM")
            preconditionFailure("Required permission was stripped instead of rejected")
        } catch SigningEntitlements.Failure.unauthorized(let key) { precondition(key == "unauthorized") }
        let disabled = try SigningEntitlements.prepare(application: ["disabled": false], profile: [:], teamID: "TEAM")
        precondition(disabled.isEmpty)
        precondition(SigningEntitlements.matchesBundleIdentifier("com.example.*", bundleIdentifier: "com.example.app"))
        precondition(!SigningEntitlements.matchesBundleIdentifier("com.example.*", bundleIdentifier: "com.examples.app"))
        precondition(!SigningEntitlements.matchesBundleIdentifier("com.example.*", bundleIdentifier: "com.example"))
        precondition(!SigningEntitlements.matchesBundleIdentifier("com.*.app", bundleIdentifier: "com.example.app"))
        let wildcard: [String: Any] = ["application-identifier": "PREFIX.*", "keychain-access-groups": ["TEAM.*"]]
        let expanded = try SigningEntitlements.prepare(application: [:], profile: wildcard, teamID: "TEAM", bundleIdentifier: "com.example.app")
        precondition(expanded["application-identifier"] as? String == "PREFIX.com.example.app")
        do {
            _ = try SigningEntitlements.prepare(application: ["com.apple.developer.networking.networkextension": ["packet-tunnel-provider"]], profile: wildcard, teamID: "TEAM", bundleIdentifier: "com.example.app")
            fatalError("Wildcard identity must not grant missing capabilities")
        } catch SigningEntitlements.Failure.unauthorized(let key) {
            precondition(key == "com.apple.developer.networking.networkextension")
        }
        let exactIdentity = try SigningEntitlements.prepare(application: [:], profile: profile,
            teamID: "TEAM", bundleIdentifier: "example.app")
        precondition(exactIdentity["application-identifier"] as? String == "TEAM.example.app")
        precondition(exactIdentity["get-task-allow"] as? Bool == true)
        precondition(exactIdentity["com.apple.security.application-groups"] == nil)
        let preservedGroup = try SigningEntitlements.prepare(
            application: ["com.apple.security.application-groups": ["group.shared.TEAM"]],
            profile: profile, teamID: "TEAM")
        precondition(preservedGroup["com.apple.security.application-groups"] as? [String] == ["group.shared.TEAM"])

        func reject(_ application: [String: Any], _ granted: [String: Any], key: String,
                    bundleIdentifier: String? = nil) throws {
            do {
                _ = try SigningEntitlements.prepare(application: application, profile: granted,
                    teamID: "TEAM", bundleIdentifier: bundleIdentifier)
                preconditionFailure("Unauthorized entitlement accepted: " + key)
            } catch SigningEntitlements.Failure.unauthorized(let failedKey) {
                precondition(failedKey == key)
            }
        }
        try reject([:], profile, key: "application-identifier", bundleIdentifier: "example.other")
        try reject([:], wildcard, key: "application-identifier")
        try reject([:], [:], key: "application-identifier", bundleIdentifier: "example.app")
        try reject([:], ["com.apple.developer.team-identifier": "OTHER"], key: "com.apple.developer.team-identifier")
        try reject(["keychain-access-groups": ["invalid"]], profile, key: "keychain-access-groups")
        try reject(["keychain-access-groups": ["OLD.example.app"]],
            ["keychain-access-groups": ["OTHER.*"]], key: "keychain-access-groups")
        try reject(["com.apple.security.application-groups": ["group.foreign"]], profile,
            key: "com.apple.security.application-groups")
        try reject(["aps-environment": "production"], ["aps-environment": "development"], key: "aps-environment")
        try reject(["capabilities": ["allowed", "forbidden"]], ["capabilities": ["allowed"]], key: "capabilities")
        try reject(["enabled": true], ["enabled": false], key: "enabled")
        try reject(["enabled": true], ["enabled": 1], key: "enabled")
        precondition(!SigningEntitlements.matchesBundleIdentifier("*", bundleIdentifier: ""))
        precondition(!SigningEntitlements.matchesBundleIdentifier("*", bundleIdentifier: "example.*"))
        print("PASS exact Apple/iOS certificate types, entitlement values, least privileges, identity remapping and missing permission rejection")
    }
}
