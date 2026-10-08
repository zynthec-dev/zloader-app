import Foundation
import Minimuxer
#if os(iOS)
import NetworkExtension
import SideSign
import SwiftUI

/// Uses only the provider embedded in this app; never stops another app's VPN.
@MainActor
final class EmbeddedTunnel {
    static let shared = EmbeddedTunnel()
    private var manager: NETunnelProviderManager?
    private var startedHere = false

    private var providerID: String? {
        // Discover the signed extension ID, including any SideSign team suffix.
        let plugins = Bundle.main.builtInPlugInsURL
        return plugins.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }?
            .compactMap { Bundle(url: $0) }
            .first { ($0.infoDictionary?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == "com.apple.networkextension.packet-tunnel" }?
            .bundleIdentifier
    }

    /// Saves the embedded provider configuration and requests iOS VPN consent.
    /// Configuration persists; connecting remains owned by operation leases.
    func configure() async throws {
        _ = try await configuredManager()
    }

    func validateInstalledAuthorization() throws {
        guard let providerID else {
            throw OperationError.invalidVPN(reason: "ZLoaderTunnel is missing from this build.")
        }
        guard let host = ALTApplication(fileURL: Bundle.main.bundleURL),
              let provider = host.appExtensions.first(where: { $0.bundleIdentifier == providerID }) else {
            throw OperationError.invalidVPN(reason: "The installed zLoader tunnel extension cannot be read. Install the complete IPA including its extensions.")
        }
        for app in [host, provider] {
            guard let profile = app.provisioningProfile,
                  profile.expirationDate > Date(),
                  PacketTunnelProvisioning.isAuthorized(by: profile.entitlements),
                  PacketTunnelProvisioning.isAuthorized(by: app.entitlements) else {
                throw OperationError.invalidVPN(reason: PacketTunnelProvisioning.installedProfileFailure(
                    for: app.bundleIdentifier, missing: app.provisioningProfile == nil,
                    expired: app.provisioningProfile.map { $0.expirationDate <= Date() } ?? false
                ))
            }
        }
    }
    var unavailableReason: String? {
        do { try validateInstalledAuthorization(); return nil }
        catch { return error.localizedDescription }
    }
    /// Read-only readiness for the status dot. An idle provider is expected to be disconnected.
    func isConfiguredAndIdle() async -> Bool {
        guard unavailableReason == nil, let providerID else { return false }
        do {
            let configurations = try await NETunnelProviderManager.loadAllFromPreferences()
            guard let selected = configurations.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerID
            }), selected.isEnabled,
                let config = selected.protocolConfiguration as? NETunnelProviderProtocol,
                let values = config.providerConfiguration,
                let peer = values["peer"] as? String, let iface = values["interface"] as? String,
                isPrivateTunnelIPv4(peer), isPrivateTunnelIPv4(iface), peer != iface else { return false }
            return selected.connection.status == .disconnected || selected.connection.status == .disconnecting
        } catch { return false }
    }

    private func configuredManager() async throws -> NETunnelProviderManager {
        try validateInstalledAuthorization()
        guard let providerID else { throw OperationError.invalidVPN(reason: "Tunnel extension missing.") }
        let configurations = try await NETunnelProviderManager.loadAllFromPreferences()
        let selected = configurations.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerID
        } ?? NETunnelProviderManager()
        manager = selected
        if selected.localizedDescription != "zLoader Local Tunnel" {
            selected.localizedDescription = "zLoader Local Tunnel"
            try await selected.saveToPreferences()
        }
        if selected.connection.status == .connected {
            // Restore the exact routed peer after relaunch or a network change.
            // A connected provider does not imply that the host's settings cache survived.
            guard let config = selected.protocolConfiguration as? NETunnelProviderProtocol,
                  let peer = config.providerConfiguration?["peer"] as? String,
                  isPrivateTunnelIPv4(peer) else {
                throw OperationError.invalidVPN(reason: "The connected internal tunnel has no valid device endpoint. Reconfigure it in Connection Settings.")
            }
            ConnectionConfig.shared.overrideTunnelPeerIp = peer
            return selected
        }
        let config = NETunnelProviderProtocol()
        config.providerBundleIdentifier = providerID
        config.serverAddress = "zLoader Local Tunnel"
        let peer = UserDefaults.standard.string(forKey: "zLoader.internalPeer") ?? "10.7.0.1"
        let iface = UserDefaults.standard.string(forKey: "zLoader.internalInterface") ?? "10.7.1.1"
        guard isPrivateTunnelIPv4(peer), isPrivateTunnelIPv4(iface), peer != iface else {
            throw OperationError.invalidParameters("Choose two different private IPv4 addresses for the local tunnel.")
        }
        config.providerConfiguration = ["peer": peer, "interface": iface]
        ConnectionConfig.shared.overrideTunnelPeerIp = peer
        selected.protocolConfiguration = config
        selected.localizedDescription = "zLoader Local Tunnel"
        selected.isEnabled = true
        selected.isOnDemandEnabled = false
        try await selected.saveToPreferences()
        try await selected.loadFromPreferences()
        try Task.checkCancellation()
        return selected
    }

    func start() async throws {
        let selected = try await configuredManager()
        if selected.connection.status == .connected { return }
        let statuses = statusChanges(selected.connection)
        startedHere = true
        try selected.connection.startVPNTunnel()
        if selected.connection.status == .connected { return }
        for await status in statuses {
            try Task.checkCancellation()
            switch status {
            case .connected: return
            case .disconnected, .invalid:
                throw OperationError.invalidVPN(reason: "The embedded tunnel could not connect. Check the Network Extension entitlement and provisioning profiles for both zLoader and ZLoaderTunnel.")
            default: continue
            }
        }
        throw CancellationError()
    }

    func stop() async {
        guard startedHere, let manager else { return }
        startedHere = false
        let statuses = statusChanges(manager.connection)
        manager.connection.stopVPNTunnel()
        if manager.connection.status == .disconnected || manager.connection.status == .invalid { return }
        for await status in statuses {
            if status == .disconnected || status == .invalid { return }
        }
    }

    @MainActor
    private final class ObservedConnection {
        let connection: NEVPNConnection
        init(_ connection: NEVPNConnection) { self.connection = connection }
    }

    private func statusChanges(_ connection: NEVPNConnection) -> AsyncStream<NEVPNStatus> {
        let observed = ObservedConnection(connection)
        return AsyncStream { continuation in
            let token = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: connection, queue: .main) { _ in
                Task { @MainActor in
                    continuation.yield(observed.connection.status)
                }
            }
            continuation.onTermination = { _ in NotificationCenter.default.removeObserver(token) }
        }
    }
}
/// Private virtual endpoints only; routing public destinations is outside this provider's scope.
func isPrivateTunnelIPv4(_ value: String) -> Bool {
    let parts = value.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
          parts.compactMap({ UInt8($0) }).count == 4 else { return false }
    let bytes = parts.compactMap { UInt8($0) }
    return bytes[0] == 10 || (bytes[0] == 172 && (16...31).contains(bytes[1])) ||
        (bytes[0] == 192 && bytes[1] == 168)
}
#endif
