import Foundation

@main
struct PacketTunnelProvisioningTests {
    static func main() {
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
