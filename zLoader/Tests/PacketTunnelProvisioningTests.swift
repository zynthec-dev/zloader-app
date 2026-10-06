import Foundation

@main
struct PacketTunnelProvisioningTests {
    static func main() {
        precondition(PacketTunnelProvisioning.appendingTeamOnce(to: "example.app", teamID: "TEAM") == "example.app.TEAM")
        precondition(PacketTunnelProvisioning.appendingTeamOnce(to: "example.app.TEAM", teamID: "TEAM") == "example.app.TEAM")
        precondition(PacketTunnelProvisioning.appendingTeamOnce(to: "example.app.TEAM.TEAM", teamID: "TEAM") == "example.app.TEAM.TEAM")
        precondition(PacketTunnelProvisioning.appendingTeamOnce(to: "example.app.MYTEAM", teamID: "TEAM") == "example.app.MYTEAM.TEAM")
        print("PASS idempotent team suffix and existing installed identities retained")
        for (missing, expired, expected) in [(true, false, "no embedded"), (false, true, "expired"), (false, false, "does not authorize")] {
            let message = PacketTunnelProvisioning.installedProfileFailure(for: "example.app", missing: missing, expired: expired)
            precondition(message.contains(expected) && message.contains("in-app refresh cannot repair"))
            precondition(!message.contains("LocalDevVPN"))
        }
        print("PASS installed profile failures distinguish missing, expired and unauthorized profiles")
        let tunnel: [String: Any] = ["NSExtension": ["NSExtensionPointIdentifier": PacketTunnelProvisioning.extensionPoint]]
        let widget: [String: Any] = ["NSExtension": ["NSExtensionPointIdentifier": "com.apple.widgetkit-extension"]]
        precondition(PacketTunnelProvisioning.requiresCapability(infoPlist: [:], extensions: [tunnel, widget]))
        precondition(PacketTunnelProvisioning.requiresCapability(infoPlist: tunnel, extensions: []))
        precondition(!PacketTunnelProvisioning.requiresCapability(infoPlist: widget, extensions: []))
        precondition(!PacketTunnelProvisioning.requiresCapability(infoPlist: [:], extensions: [widget]))
        print("PASS host/provider capability detection; widgets and ordinary apps excluded")

        let cached: [String: Any] = ["com.apple.security.application-groups": ["group.example.app"]]
        let request = PacketTunnelProvisioning.requestedEntitlements(cached, required: true)
        precondition(PacketTunnelProvisioning.isAuthorized(by: request))
        precondition(request["com.apple.security.application-groups"] as? [String] == ["group.example.app"])
        precondition(cached[PacketTunnelProvisioning.entitlement] == nil)
        precondition(PacketTunnelProvisioning.requestedEntitlements(cached, required: false)[PacketTunnelProvisioning.entitlement] == nil)
        let multiple = PacketTunnelProvisioning.requestedEntitlements(
            [PacketTunnelProvisioning.entitlement: ["app-proxy-provider"]], required: true
        )
        let again = PacketTunnelProvisioning.requestedEntitlements(multiple, required: true)
        precondition(again[PacketTunnelProvisioning.entitlement] as? [String] == ["app-proxy-provider", "packet-tunnel-provider"])
        print("PASS stale entitlement recovery, unrelated values preserved and idempotent requests")

        // A requested capability must never modify or replace Apple's authorization response.
        precondition(!PacketTunnelProvisioning.isAuthorized(by: cached))
        precondition(!PacketTunnelProvisioning.isAuthorized(by: [PacketTunnelProvisioning.entitlement: []]))
        precondition(!PacketTunnelProvisioning.isAuthorized(by: [PacketTunnelProvisioning.entitlement: ["app-proxy-provider"]]))
        precondition(!PacketTunnelProvisioning.isAuthorized(by: [PacketTunnelProvisioning.entitlement: "packet-tunnel-provider"]))
        precondition(PacketTunnelProvisioning.isAuthorized(by: [PacketTunnelProvisioning.entitlement: ["packet-tunnel-provider"]]))
        print("PASS Apple response validation rejects missing, wrong and malformed authorizations")
    }
}
