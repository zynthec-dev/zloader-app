import Foundation
import Minimuxer

/// Prepare device services through the user's external local VPN tunnel.
/// zLoader never creates, starts or stops a VPN configuration.
enum ZLoaderTransport {
    static let leases = TransportLeaseCoordinator(start: {
        #if os(iOS) && !targetEnvironment(simulator)
        await MainActor.run {
            ConnectionConfig.shared.useLocalVPN = true
            ConnectionConfig.shared.overrideTunnelPeerIp = ""
        }
        try await WireGuardLocalTunnel.shared.prepare()
        syncMinimuxerBackendFromUserDefaults()
        await minimuxer.network.refreshEndpoint()
        #endif
    }, stop: {})

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
