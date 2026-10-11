import Foundation

@main
struct WireGuardConfigurationTests {
    static func main() throws {
        if CommandLine.arguments.count > 1 {
            _ = try WireGuardConfiguration.validated(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            print("PASS pinned upstream WireGuard configuration")
        }
        // Synthetic bytes only, not actual VPN or signing keys.
        let fixtureKey = Data(repeating: 0, count: 32).base64EncodedString()
        let input = """
        [Interface]
        PrivateKey = \(fixtureKey)
        Address = 10.7.0.10/24
        DNS = 1.1.1.1
        [Peer]
        PublicKey = \(fixtureKey)
        AllowedIPs = 0.0.0.0/0
        Endpoint = 127.0.0.1:51820
        PersistentKeepalive = 25
        """
        let result = try WireGuardConfiguration.validated(Data(input.utf8))
        let text = String(decoding: result, as: UTF8.self)
        precondition(text.contains("AllowedIPs = 10.7.0.1/32"))
        precondition(!text.contains("DNS") && !text.contains("0.0.0.0/0"))
        let cached = try WireGuardConfiguration.validated(result)
        precondition(cached == result)
        for unsafe in [input.replacingOccurrences(of: "127.0.0.1:51820", with: "example.com:51820"),
                       input.replacingOccurrences(of: "10.7.0.10/24", with: "10.0.0.1/24"),
                       input.replacingOccurrences(of: fixtureKey, with: "invalid"), "invalid"] {
            do {
                _ = try WireGuardConfiguration.validated(Data(unsafe.utf8))
                fatalError("Invalid WireGuard parameters accepted")
            } catch WireGuardConfiguration.Failure.invalidConfiguration { }
        }
        print("PASS WireGuard loopback config: device-only route, no DNS replacement, invalid inputs rejected and cache round-trip")
    }
}
