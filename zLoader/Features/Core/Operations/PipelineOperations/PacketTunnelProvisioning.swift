import Foundation

/// Requests required capabilities; only the returned Apple profile can authorize them.
enum PacketTunnelProvisioning {
    static let entitlement = "com.apple.developer.networking.networkextension"
    static let provider = "packet-tunnel-provider"
    static let extensionPoint = "com.apple.networkextension.packet-tunnel"

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

    static func installedProfileFailure(for bundleID: String, missing: Bool, expired: Bool) -> String {
        let problem = missing ? "has no embedded provisioning profile" :
            expired ? "has an expired provisioning profile" :
            "has a provisioning profile that does not authorize packet-tunnel-provider"
        return "The installed bundle \(bundleID) \(problem). " +
            "The embedded VPN cannot start, so an in-app refresh cannot repair this installation. " +
            "Install an Apple-signed build for this exact app ID and App Group, with Network Extensions authorized " +
            "in both the host and tunnel profiles. Keep all extensions and do not delete the app. " +
            "A paid Apple ID or a different certificate alone does not add this permission to an installed profile."
    }

    static func failureMessage(for bundleID: String) -> String {
        "Apple's provisioning profile for \(bundleID) does not authorize packet-tunnel-provider. " +
        "The profile used for an Xcode installation is separate from the profile requested by zLoader. " +
        "Use the same eligible paid developer team, enable Network Extensions for the host and tunnel App IDs " +
        "at developer.apple.com/account/resources/identifiers/list, then regenerate their development profiles and retry. " +
        "If Apple's returned profile still omits this capability, zLoader cannot self-sign or refresh its embedded tunnel."
    }
}
