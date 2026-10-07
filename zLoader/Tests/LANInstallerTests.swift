import Foundation
import Security

@main
struct LANInstallerTests {
    static func main() throws {
        let request = try LANHTTP.parse(Data("GET /token/app.ipa HTTP/1.1\r\nRange: bytes=2-4\r\n\r\n".utf8))
        precondition(request.path == "/token/app.ipa")
        let explicit = try LANHTTP.bytes(request.range, size: 10)
        let suffix = try LANHTTP.bytes("bytes=-3", size: 10)
        let open = try LANHTTP.bytes("bytes=5-", size: 10)
        let bounded = try LANHTTP.bytes("bytes=0-100", size: 10)
        precondition(explicit == 2..<5 && suffix == 7..<10 && open == 5..<10 && bounded == 0..<10)
        for range in ["bytes=10-", "bytes=9-2", "bytes=0-1,3-4", "bytes=-0", "bytes=18446744073709551616-"] {
            do { _ = try LANHTTP.bytes(range, size: 10); fatalError("Invalid range accepted") } catch LANHTTP.Failure.badRange { }
        }
        for raw in ["POST / HTTP/1.1\r\n\r\n", "GET /../secret HTTP/1.1\r\n\r\n", "GET /%2e HTTP/1.1\r\n\r\n", "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n", "GET / HTTP/1.1\r\nRange: bytes=0-1\r\nRange: bytes=2-3\r\n\r\n"] {
            do { _ = try LANHTTP.parse(Data(raw.utf8)); fatalError("Invalid request accepted") } catch LANHTTP.Failure.badRequest { }
        }
        let base = URL(string: "https://192.168.1.2:1234/token/")!
        let manifest = try LANHTTP.manifest(base: base, bundleID: "com.example.test", version: "42", name: "Fixture")
        let plist = try PropertyListSerialization.propertyList(from: manifest, format: nil) as! [String: Any]
        let items = plist["items"] as! [[String: Any]]
        precondition((items[0]["metadata"] as! [String: String])["bundle-version"] == "42")
        let page = String(data: LANHTTP.page(base: base, name: "<script>"), encoding: .utf8)!
        precondition(!page.contains("<script>") && page.contains("itms-services://"))
        let ca = try LANCertificate.createAuthority(name: "zLoader Test Device")
        let identity = try LANCertificate.identity(authority: ca, ip: "192.168.1.2", name: "zLoader Test Device")
        defer { identity.remove() }
        let caCert = SecCertificateCreateWithData(nil, ca.certificate as CFData)!
        let policy = SecPolicyCreateSSL(true, "192.168.1.2" as CFString)
        var trust: SecTrust?
        precondition(SecTrustCreateWithCertificates([identity.certificate, caCert] as CFArray, policy, &trust) == errSecSuccess)
        precondition(SecTrustSetAnchorCertificates(trust!, [caCert] as CFArray) == errSecSuccess)
        precondition(SecTrustSetAnchorCertificatesOnly(trust!, true) == errSecSuccess)
        var error: CFError?
        precondition(SecTrustEvaluateWithError(trust!, &error), "TLS trust failed: \(String(describing: error))")
        let wrongHost = SecPolicyCreateSSL(true, "192.168.1.3" as CFString)
        SecTrustSetPolicies(trust!, wrongHost)
        precondition(!SecTrustEvaluateWithError(trust!, nil), "Wrong IP was trusted")
        let profile = try LANCertificate.trustProfile(authority: ca, name: "zLoader Test Device")
        precondition(!profile.contains(ca.privateKey))
        let directory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/zloader-lan-tests", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ca.certificate.write(to: directory.appendingPathComponent("ca.der"))
        try (SecCertificateCopyData(identity.certificate) as Data).write(to: directory.appendingPathComponent("server.der"))
        print("PASS HTTP validation, bounded ranges, manifest, escaped HTML, Apple TLS trust, wrong-host rejection and public-only trust profile")
    }
}
