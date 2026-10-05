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

    private func configuredManager() async throws -> NETunnelProviderManager {
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
                  PacketTunnelProvisioning.isAuthorized(by: profile.entitlements) else {
                throw OperationError.invalidVPN(reason: PacketTunnelProvisioning.failureMessage(for: app.bundleIdentifier))
            }
        }
        let configurations = try await NETunnelProviderManager.loadAllFromPreferences()
        let selected = configurations.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerID
        } ?? NETunnelProviderManager()
        manager = selected
        if selected.connection.status == .connected { return selected }
        let config = NETunnelProviderProtocol()
        config.providerBundleIdentifier = providerID
        config.serverAddress = "zLoader local device tunnel"
        selected.protocolConfiguration = config
        selected.localizedDescription = "zLoader"
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
/// Shared by onboarding and connection settings; success means saved, not connected.
struct EmbeddedTunnelSetupView: View {
    @State private var configuring = false
    @State private var configured = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("zLoader uses its embedded local VPN for device services. Allow the iOS VPN configuration prompt. The tunnel connects only while an operation needs it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            SwiftUI.Button(configured ? "Configure zLoader VPN Again" : "Configure zLoader VPN") {
                configuring = true
                message = nil
                Task { @MainActor in
                    defer { configuring = false }
                    do {
                        try await EmbeddedTunnel.shared.configure()
                        configured = true
                        message = "zLoader VPN configuration saved. Pairing and refresh will start the tunnel when needed."
                    } catch {
                        configured = false
                        let failure = error as NSError
                        message = "\(error.localizedDescription) (\(failure.domain), \(failure.code))"
                    }
                }
            }
            .disabled(configuring)
            if configuring { ProgressView() }
            if let message { Text(message).font(.footnote).textSelection(.enabled) }
        }
    }
}
#endif

enum ZLoaderTransport {
    static let leases = TransportLeaseCoordinator(start: {
        #if os(iOS) && !targetEnvironment(simulator)
        syncMinimuxerBackendFromUserDefaults()
        guard await getDeviceConnectionMode() == .localVPN else { return }
        try await EmbeddedTunnel.shared.start()
        await minimuxer.network.refreshEndpoint()
        #endif
    }, stop: {
        #if os(iOS) && !targetEnvironment(simulator)
        await EmbeddedTunnel.shared.stop()
        #endif
    })

    static func withLease<T>(_ operation: () async throws -> T) async throws -> T {
        let id = try await leases.acquire()
        do {
            try Task.checkCancellation()
            let result = try await operation()
            await leases.release(id)
            return result
        } catch {
            await leases.release(id)
            throw error
        }
    }
}
