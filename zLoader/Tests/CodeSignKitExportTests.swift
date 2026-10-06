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
        print("PASS pinned CodeSignKit imports ASCII/Unicode encrypted exports, preserves private key and rejects wrong password")
    }
}
