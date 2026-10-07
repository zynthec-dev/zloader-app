import Foundation
import Security

/// Local test harness; no Apple-account data or user signing identities are used.
@main
struct LANServerFixture {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        guard let ip = LANIPAServer.wifiAddress() else { fatalError("Wi-Fi IPv4 is required for this integration test") }
        let authority = try LANCertificate.createAuthority(name: "zLoader LAN test")
        try PortablePKCS12.pem(authority.certificate, label: "CERTIFICATE").write(to: directory.appendingPathComponent("ca.pem"))
        let stopped = DispatchSemaphore(value: 0)
        let server = LANIPAServer { status in
            let values: [String: Any] = ["url": status.url?.absoluteString ?? "", "progress": status.progress,
                "complete": status.complete, "error": status.error ?? ""]
            do {
                try JSONSerialization.data(withJSONObject: values).write(to: directory.appendingPathComponent("status.json"), options: .atomic)
            } catch { fatalError("Could not write fixture status: \(error)") }
            if status.url == nil { stopped.signal() }
        }
        server.start(ipa: directory.appendingPathComponent("fixture.ipa"), ip: ip, name: "Test app", bundleID: "com.example.fixture", version: "42", authority: authority)
        while let line = readLine() {
            if line == "stop" {
                server.stop()
                guard stopped.wait(timeout: .now() + 5) == .success else { fatalError("Server did not stop") }
                return
            }
        }
        server.stop()
        _ = stopped.wait(timeout: .now() + 5)
    }
}
