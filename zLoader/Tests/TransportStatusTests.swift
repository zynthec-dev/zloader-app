import Foundation

@main
struct TransportStatusTests {
    static func main() {
        typealias S = TransportStatusPresentation
        precondition(S.resolve(ready: true, failure: nil, hasTunnelInterface: true, peerReachable: true) == .ready)
        precondition(S.resolve(ready: true, failure: .device, hasTunnelInterface: false, peerReachable: true) == .ready)
        precondition(S.resolve(ready: false, failure: .tunnel, hasTunnelInterface: false, peerReachable: false) == .tunnelMissing)
        precondition(S.resolve(ready: false, failure: .tunnel, hasTunnelInterface: true, peerReachable: false) == .tunnelUnreachable)
        precondition(S.resolve(ready: false, failure: .tunnel, hasTunnelInterface: false, peerReachable: true) == .tunnelUnreachable)
        for (failure, expected) in [(S.Failure.pairingRequired,S.pairingRequired),(.pairingFailed,.pairingFailed),(.incompatiblePairing,.incompatiblePairing),(.starting,.starting),(.device,.deviceUnavailable)] {
            for interface in [false,true] {
                for peer in [false,true] {
                    let status = S.resolve(ready: false, failure: failure, hasTunnelInterface: interface, peerReachable: peer)
                    precondition(status == expected)
                    precondition(status.messageKey != "Local Tunnel Missing")
                }
            }
        }
        print("PASS tunnel absence, reachable peer, pairing incompatibility, startup and other service errors are distinguished")
    }
}
