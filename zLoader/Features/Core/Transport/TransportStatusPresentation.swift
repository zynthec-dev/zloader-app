import Foundation

/// A device-service failure must not masquerade as a missing VPN.
enum TransportStatusPresentation: Equatable {
    enum Failure { case tunnel, pairingRequired, pairingFailed, incompatiblePairing, starting, device }
    case ready, tunnelMissing, tunnelUnreachable, pairingRequired, pairingFailed, incompatiblePairing, starting, deviceUnavailable

    static func resolve(ready: Bool, failure: Failure?, hasTunnelInterface: Bool, peerReachable: Bool) -> Self {
        if ready { return .ready }
        switch failure {
        case .tunnel:
            return hasTunnelInterface || peerReachable ? .tunnelUnreachable : .tunnelMissing
        case .pairingRequired: return .pairingRequired
        case .pairingFailed: return .pairingFailed
        case .incompatiblePairing: return .incompatiblePairing
        case .starting: return .starting
        case .device, nil: return .deviceUnavailable
        }
    }

    var messageKey: String? {
        switch self {
        case .ready: return nil
        case .tunnelMissing: return "Local Tunnel Missing"
        case .tunnelUnreachable: return "Local Tunnel Endpoint Unreachable"
        case .pairingRequired: return "Pairing Required"
        case .pairingFailed: return "Pairing Failed"
        case .incompatiblePairing: return "Pairing Incompatible With Tunnel"
        case .starting: return "Device Service Starting"
        case .deviceUnavailable: return "Device Service Unavailable"
        }
    }
}
