import Foundation

@main
struct ManagedSigningTests {
    static func main() throws {
        precondition(CertificateType.development.portalType == "DEVELOPMENT")
        precondition(CertificateType.iosDevelopment.portalType == "IOS_DEVELOPMENT")
        precondition(CertificateType.distribution.portalType == "DISTRIBUTION")
        precondition(CertificateType.iosDistribution.portalType == "IOS_DISTRIBUTION")
        precondition(CertificateType.developerID.portalType == nil)
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
        print("PASS exact Apple/iOS certificate types, entitlement values, least privileges, identity remapping and missing permission rejection")
    }
}
