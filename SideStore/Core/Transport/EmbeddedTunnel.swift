import Foundation
import Minimuxer
#if os(iOS)
import NetworkExtension

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

    func start() async throws {
        guard let providerID else {
            throw OperationError.invalidVPN(reason: "ZLoaderTunnel is missing from this build.")
        }
        let configurations = try await NETunnelProviderManager.loadAllFromPreferences()
        let selected = configurations.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerID
        } ?? NETunnelProviderManager()
        manager = selected
        if selected.connection.status == .connected { return }
        let config = NETunnelProviderProtocol()
        config.providerBundleIdentifier = providerID
        config.serverAddress = "ZLoader local device tunnel"
        selected.protocolConfiguration = config
        selected.localizedDescription = "ZLoader"
        selected.isEnabled = true
        selected.isOnDemandEnabled = false
        try await selected.saveToPreferences()
        try await selected.loadFromPreferences()
        try Task.checkCancellation()
        let statuses = statusChanges(selected.connection)
        startedHere = true
        try selected.connection.startVPNTunnel()
        for await _ in statuses {
            try Task.checkCancellation()
            switch selected.connection.status {
            case .connected: return
            case .disconnected, .invalid:
                throw OperationError.invalidVPN(reason: "The embedded tunnel could not connect. Check the Network Extension entitlement and provisioning profiles for both ZLoader and ZLoaderTunnel.")
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
        for await _ in statuses {
            if manager.connection.status == .disconnected || manager.connection.status == .invalid { return }
        }
    }

    private func statusChanges(_ connection: NEVPNConnection) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let token = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: connection, queue: .main) { _ in
                continuation.yield(())
            }
            continuation.yield(())
            continuation.onTermination = { _ in NotificationCenter.default.removeObserver(token) }
        }
    }
}
#endif

enum ZLoaderTransport {
    static let leases = TransportLeaseCoordinator(start: {
        #if os(iOS) && !targetEnvironment(simulator)
        await syncMinimuxerBackendFromUserDefaults()
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
