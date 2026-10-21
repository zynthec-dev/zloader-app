import Foundation
import CodeSignKit

@main struct CodeSignKitExportTests {
    static func main() throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let certificate = try Data(contentsOf: folder.appendingPathComponent("certificate.der"))
        let key = try Data(contentsOf: folder.appendingPathComponent("private.pem"))
        for password in ["test-password", "Grün🔑123"] {
            let exported = try PortablePKCS12.build(certificate: certificate, key: key, password: password, name: "zLoader Test")
            let parsed = try PKCS12Parser(p12Data: exported, password: password)
            guard let decodedKey = parsed.privateKeyDER else { fatalError("Missing key after import") }
            precondition(parsed.leafCertificate != nil && parsed.rsaPrivateKey != nil)
            precondition(PortablePKCS12.rsaKeyDER(decodedKey) == PortablePKCS12.rsaKeyDER(key))
            do {
                _ = try PKCS12Parser(p12Data: exported, password: "incorrect")
                fatalError("Wrong password accepted by signing parser")
            } catch {}
        }
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>com.apple.developer.carplay-audio</key><true/><key>get-task-allow</key><true/><key>test-array</key><array><string>one</string><string>two</string></array></dict></plist>
        """
        // Exact bytes generated independently by Apple's codesign for this plist.
        let expected = "705c020101b05730260c21636f6d2e6170706c652e646576656c6f7065722e636172706c61792d617564696f0101ff30130c0e6765742d7461736b2d616c6c6f770101ff30180c0a746573742d6172726179300a0c036f6e650c0374776f"
        let actual = DEREncoder.encodePlistXML(xml)!
        precondition(actual.map { String(format: "%02x", $0) }.joined() == expected)
        let executable = folder.appendingPathComponent("fixture")
        let signed = try MachOSigner(binaryData: Data(contentsOf: executable), bundleIdentifier: "test.der",
            teamIdentifier: nil, entitlementsXML: xml, infoPlistData: nil,
            codeResourcesData: nil, cmsSigner: nil, options: [.adHoc]).sign()
        try signed.write(to: executable)
        print("PASS canonical DER matches Apple reference and MachOSigner produces regression fixture")
        print("PASS pinned CodeSignKit imports ASCII/Unicode encrypted exports, preserves private key and rejects wrong password")
    }
}
