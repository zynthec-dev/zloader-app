import Foundation
import Minimuxer

/// Operation-scoped ownership of the optional embedded tunnel. External VPN
/// activation belongs to External Local VPN Tunnel or the configured Shortcuts hooks.
enum ZLoaderTransport {
    static let leases = TransportLeaseCoordinator(start: {
        #if os(iOS) && !targetEnvironment(simulator)
        await MainActor.run {
            ConnectionConfig.shared.useLocalVPN = true
            if !UserDefaults.standard.bool(forKey: "zLoader.useInternalVPN") {
                ConnectionConfig.shared.overrideTunnelPeerIp = ""
            }
        }
        syncMinimuxerBackendFromUserDefaults()
        if await MainActor.run(body: { UserDefaults.standard.bool(forKey: "zLoader.useInternalVPN") }) {
            try await EmbeddedTunnel.shared.start()
        }
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
