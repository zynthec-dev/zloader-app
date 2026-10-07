import AppIntents
import NetworkExtension

/// Local loopback routing, based on the StosVPN / External Local VPN Tunnel packet reflection
/// design. No default route or DNS override: Internet signing remains on Wi-Fi
/// or cellular. Same-device cellular behavior needs proper testing on hardware.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var running = false

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let values = (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration
        let peer = values?["peer"] as? String ?? "10.7.0.1"
        let iface = values?["interface"] as? String ?? "10.7.1.1"
        // There is no remote VPN server: packets are reflected on this device.
        // iOS automatically excludes tunnelRemoteAddress from VPN routing, so
        // using the device peer here can exclude the very endpoint we need.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let ipv4 = NEIPv4Settings(addresses: [iface], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: peer, subnetMask: "255.255.255.255")]
        // The single /32 is the entire split tunnel. Do not exclude 0.0.0.0/0:
        // it overlaps the included device route. Internet keeps its physical route.
        ipv4.excludedRoutes = []
        settings.ipv4Settings = ipv4
        setTunnelNetworkSettings(settings) { error in
            if error == nil {
                self.running = true
                self.readPackets()
            }
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        running = false
        completionHandler()
    }

    private func readPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self, self.running else { return }
            var reflected: [Data] = []
            var families: [NSNumber] = []
            for (packet, family) in zip(packets, protocols) {
                guard family.int32Value == AF_INET, packet.count >= 20 else { continue }
                var bytes = [UInt8](packet)
                guard bytes[0] >> 4 == 4, Int(bytes[0] & 15) * 4 >= 20,
                      Int(bytes[0] & 15) * 4 <= bytes.count else { continue }
                // Swap addresses bytewise (no unaligned UInt32 access). Swapping
                // preserves the IPv4 and TCP/UDP pseudo-header checksum sums.
                let source = Array(bytes[12..<16])
                bytes.replaceSubrange(12..<16, with: bytes[16..<20])
                bytes.replaceSubrange(16..<20, with: source)
                reflected.append(Data(bytes))
                families.append(family)
            }
            if !reflected.isEmpty { self.packetFlow.writePackets(reflected, withProtocols: families) }
            self.readPackets()
        }
    }
}
