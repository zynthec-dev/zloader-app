import Foundation

/// Requests required capabilities; only the returned Apple profile can authorize them.
enum PacketTunnelProvisioning {
    static let entitlement = "com.apple.developer.networking.networkextension"
    static let provider = "packet-tunnel-provider"
    static let extensionPoint = "com.apple.networkextension.packet-tunnel"

    static func appendingTeamOnce(to bundleID: String, teamID: String) -> String {
        guard !teamID.isEmpty, !bundleID.hasSuffix("." + teamID) else { return bundleID }
        return bundleID + "." + teamID
    }

    static func preservedHostIdentity(bundleID: String, profileTeam: String?, selectedTeam: String) -> String? {
        guard !bundleID.isEmpty, !selectedTeam.isEmpty, profileTeam == selectedTeam else { return nil }
        return bundleID
    }

    static func extensionBundleIdentifier(_ child: String, parent: String, resolvedParent: String) -> String? {
        guard child.hasPrefix(parent + ".") else { return nil }
        return resolvedParent + child.dropFirst(parent.count)
    }

    static func isProvider(_ infoPlist: [String: Any]) -> Bool {
        (infoPlist["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == extensionPoint
    }

    static func requiresCapability(infoPlist: [String: Any], extensions: [[String: Any]]) -> Bool {
        isProvider(infoPlist) || extensions.contains(where: isProvider)
    }

    static func requestedEntitlements(_ entitlements: [String: Any], required: Bool) -> [String: Any] {
        guard required else { return entitlements }
        var requested = entitlements
        var providers = requested[entitlement] as? [String] ?? []
        if !providers.contains(provider) { providers.append(provider) }
        requested[entitlement] = providers
        return requested
    }

    static func isAuthorized(by entitlements: [String: Any]) -> Bool {
        (entitlements[entitlement] as? [String])?.contains(provider) == true
    }

    static func failureMessage(for bundleID: String) -> String {
        "Apple's provisioning profile for \(bundleID) does not authorize packet-tunnel-provider. " +
        "zLoader requested the capability, but Apple did not return the required authorization. " +
        "Check the selected paid team and its permissions. This app requires an authorized VPN extension profile; no required entitlement was removed."
    }
}
