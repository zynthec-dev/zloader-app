import Foundation

/// Accept only the public loopback fixture matching the pinned EMProxy dependency.
/// No user's VPN credentials are requested or stored in the repository.
enum WireGuardConfiguration {
    static let sourceURL = URL(string: "https://raw.githubusercontent.com/SideStore/em_proxy/v0.9.3/keys/emp.conf")!

    static func validated(_ data: Data) throws -> Data {
        guard let text = String(data: data, encoding: .utf8), data.count < 8192 else { throw Failure.invalidConfiguration }
        var section = ""
        var interface: [String: String] = [:]
        var peer: [String: String] = [:]
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line == "[Interface]" || line == "[Peer]" { section = line; continue }
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { throw Failure.invalidConfiguration }
            if section == "[Interface]" { interface[parts[0]] = parts[1] }
            else if section == "[Peer]" { peer[parts[0]] = parts[1] }
            else { throw Failure.invalidConfiguration }
        }
        guard interface["Address"] == "10.7.0.10/24", peer["Endpoint"] == "127.0.0.1:51820",
              let privateKey = interface["PrivateKey"], Data(base64Encoded: privateKey)?.count == 32,
              let publicKey = peer["PublicKey"], Data(base64Encoded: publicKey)?.count == 32 else {
            throw Failure.invalidConfiguration
        }
        // Only route the local device service. Do not replace DNS or the internet route.
        return Data("""
        [Interface]
        PrivateKey = \(privateKey)
        Address = 10.7.0.10/24

        [Peer]
        PublicKey = \(publicKey)
        AllowedIPs = 10.7.0.1/32
        Endpoint = 127.0.0.1:51820
        PersistentKeepalive = 25

        """.utf8)
    }

    enum Failure: Error, LocalizedError {
        case invalidConfiguration
        var errorDescription: String? { NSLocalizedString("The WireGuard configuration could not be verified. Please try again.", comment: "") }
    }
}
