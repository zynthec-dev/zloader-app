import Foundation

@main
struct EmbeddedProfileReuseTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1000)
        let original = Data([1, 2, 3]) // Synthetic certificate bytes, not an Apple certificate.
        let values: [String: Any] = [PacketTunnelProvisioning.entitlement: [PacketTunnelProvisioning.provider],
                                     "com.apple.security.application-groups": ["group.example.test"]]
        let target = ProfileReuseRequirements(bundleID: "example.test", teamID: "test-team", certificate: original,
                                             deviceID: "synthetic-device", entitlements: values)
        func profile(bundle: String = "example.test", team: String = "test-team", expiry: Double = 2000,
                     certificates: [Data] = [original], devices: [String] = ["synthetic-device"],
                     entitlements: [String: Any] = values) -> EmbeddedProfileSnapshot {
            EmbeddedProfileSnapshot(bundleID: bundle, teamID: team, expiresAt: Date(timeIntervalSince1970: expiry),
                                    certificates: certificates, devices: devices, entitlements: entitlements)
        }
        precondition(EmbeddedProfileReuse.accepts(profile(), for: target, now: now))
        for invalid in [profile(bundle: "example.other"), profile(team: "other-team"), profile(expiry: 999),
                        profile(certificates: [Data([4])]), profile(devices: ["other-device"]),
                        profile(entitlements: [:]),
                        profile(entitlements: [PacketTunnelProvisioning.entitlement: [PacketTunnelProvisioning.provider]])] {
            precondition(!EmbeddedProfileReuse.accepts(invalid, for: target, now: now))
        }
        precondition(EmbeddedProfileReuse.accepts(profile(devices: ["SYNTHETIC-DEVICE"]), for: target, now: now))
        print("PASS embedded profile reuse: exact identity/team/certificate, expiry/device and all required capabilities; seven incompatible cases rejected")
    }
}
