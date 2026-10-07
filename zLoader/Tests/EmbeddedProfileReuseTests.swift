import Foundation

@main
struct EmbeddedProfileReuseTests {
    static func main() {
        precondition(PacketTunnelProvisioning.extensionBundleIdentifier("example.app.tunnel", parent: "example.app", resolvedParent: "example.app") == "example.app.tunnel")
        precondition(PacketTunnelProvisioning.extensionBundleIdentifier("example.app.tunnel", parent: "example.app", resolvedParent: "example.app.TEAM") == "example.app.TEAM.tunnel")
        precondition(PacketTunnelProvisioning.extensionBundleIdentifier("example.application.tunnel", parent: "example.app", resolvedParent: "example.app.TEAM") == nil)
        print("PASS extension identities follow the resolved host; prefix collisions rejected")
        precondition(PacketTunnelProvisioning.preservedHostIdentity(bundleID: "example.app.debug.TEAM", profileTeam: "TEAM", selectedTeam: "TEAM") == "example.app.debug.TEAM")
        precondition(PacketTunnelProvisioning.preservedHostIdentity(bundleID: "example.app", profileTeam: "OTHER", selectedTeam: "TEAM") == nil)
        precondition(PacketTunnelProvisioning.preservedHostIdentity(bundleID: "example.app", profileTeam: nil, selectedTeam: "TEAM") == nil)
        let base = "zLoader example.app CERT"
        precondition(ManagedProfileNaming.isOwned(base, base: base))
        let first = ManagedProfileNaming.uniqueName(base: base, identity: "PROFILE1")
        let second = ManagedProfileNaming.uniqueName(base: base, identity: "PROFILE2")
        precondition(first != second)
        precondition(first == ManagedProfileNaming.uniqueName(base: base, identity: "PROFILE1"))
        precondition(ManagedProfileNaming.isOwned(first, base: base))
        precondition(!ManagedProfileNaming.isOwned(base + "OTHER [PROFILE1]", base: base))
        precondition(!ManagedProfileNaming.isOwned("Xcode " + first, base: base))
        print("PASS duplicate legacy names migrate to stable per-profile names; unrelated names excluded")
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
        precondition(EmbeddedProfileReuse.accepts(profile(), for: target, requiredDevices: ["SYNTHETIC-DEVICE"], now: now))
        precondition(!EmbeddedProfileReuse.accepts(profile(), for: target, requiredDevices: ["synthetic-device", "sharing-device"], now: now))
        precondition(EmbeddedProfileReuse.accepts(profile(devices: ["synthetic-device", "SHARING-DEVICE"]), for: target,
            requiredDevices: ["synthetic-device", "sharing-device"], now: now))
        print("PASS existing profiles reused only when all requested devices are authorized")
        for invalid in [profile(bundle: "example.other"), profile(team: "other-team"), profile(expiry: 999),
                        profile(certificates: [Data([4])]), profile(devices: ["other-device"]),
                        profile(entitlements: [:]),
                        profile(entitlements: [PacketTunnelProvisioning.entitlement: [PacketTunnelProvisioning.provider]])] {
            precondition(!EmbeddedProfileReuse.accepts(invalid, for: target, now: now))
        }
        let deviceFailures = EmbeddedProfileReuse.incompatibilities(profile(devices: ["other-device"]), for: target, now: now)
        precondition(deviceFailures == ["current device is not authorized"])
        let groupFailures = EmbeddedProfileReuse.incompatibilities(profile(entitlements: [PacketTunnelProvisioning.entitlement: [PacketTunnelProvisioning.provider]]), for: target, now: now)
        precondition(groupFailures.count == 1 && groupFailures[0].contains("application-groups"))
        precondition(!groupFailures[0].contains("networkextension"))
        print("PASS exact profile rejection diagnostics without falsely claiming missing VPN authorization")
        let rotated = Data([4, 5, 6])
        let rotatedTarget = ProfileReuseRequirements(bundleID: target.bundleID, teamID: target.teamID,
                                                     certificate: rotated, deviceID: target.deviceID, entitlements: values)
        precondition(!EmbeddedProfileReuse.accepts(profile(), for: rotatedTarget, now: now))
        precondition(EmbeddedProfileReuse.accepts(profile(certificates: [rotated]), for: rotatedTarget, now: now))
        print("PASS certificate rotation requires a newly authorized profile; original Xcode key is not required")
        precondition(EmbeddedProfileReuse.accepts(profile(devices: ["SYNTHETIC-DEVICE"]), for: target, now: now))
        print("PASS embedded profile reuse: exact identity/team/certificate, expiry/device and all required capabilities; seven incompatible cases rejected")
        let general: [String: Any] = ["com.apple.developer.associated-domains": ["applinks:example.test"],
                                      "com.apple.developer.siri": true,
                                      "aps-environment": "development",
                                      "keychain-access-groups": ["OLD.example.test"]]
        let generalTarget = ProfileReuseRequirements(bundleID: target.bundleID, teamID: target.teamID,
                                                     certificate: original, deviceID: target.deviceID, entitlements: general)
        let permitted: [String: Any] = ["com.apple.developer.associated-domains": ["*"],
                                        "com.apple.developer.siri": true,
                                        "aps-environment": "development",
                                        "keychain-access-groups": ["test-team.*"]]
        precondition(EmbeddedProfileReuse.accepts(profile(entitlements: permitted), for: generalTarget, now: now))
        for key in general.keys {
            var missing = permitted
            missing.removeValue(forKey: key)
            precondition(!EmbeddedProfileReuse.accepts(profile(entitlements: missing), for: generalTarget, now: now))
        }
        var wrongEnvironment = permitted
        wrongEnvironment["aps-environment"] = "production"
        precondition(!EmbeddedProfileReuse.accepts(profile(entitlements: wrongEnvironment), for: generalTarget, now: now))
        print("PASS general capability authorization, Apple wildcard allow-lists, keychain team remapping and push environment mismatch")
    }
}
