import Foundation
import Security
@main struct PortablePKCS12Tests {
    static func main() throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let cert = try Data(contentsOf: folder.appendingPathComponent("certificate.der"))
        let key = try Data(contentsOf: folder.appendingPathComponent("private.pem"))
        let wrongKey = try Data(contentsOf: folder.appendingPathComponent("other.pem"))
        print("TEST generated certificate and matching key")
        for (index, password) in ["test-password", "Grün🔑123"].enumerated() {
            let p12 = try PortablePKCS12.build(certificate: cert, key: key, password: password, name: "zLoader Test")
            try p12.write(to: folder.appendingPathComponent("export\(index).p12"))
            var items: CFArray?
            let options = [kSecImportExportPassphrase: password, kSecImportToMemoryOnly: true] as CFDictionary
            precondition(SecPKCS12Import(p12 as CFData, options, &items) == errSecSuccess)
            precondition((items as? [[String: Any]])?.first?[kSecImportItemIdentity as String] != nil)
            let wrong = [kSecImportExportPassphrase: "incorrect", kSecImportToMemoryOnly: true] as CFDictionary
            precondition(SecPKCS12Import(p12 as CFData, wrong, &items) != errSecSuccess)
        }
        do {
            _ = try PortablePKCS12.build(certificate: cert, key: wrongKey, password: "test", name: "Mismatch")
            fatalError("Mismatched key accepted")
        } catch PortablePKCS12.Failure.keyMismatch {}
        print("TEST generate local CSR")
        let request = try PortablePKCS12.generateRequest(commonName: "zLoader Local Request", email: "local@example.invalid", organization: "zLoader")
        try request.csr.write(to: folder.appendingPathComponent("request.csr"))
        try request.privateKey.write(to: folder.appendingPathComponent("request.key"))
        try request.publicKey.write(to: folder.appendingPathComponent("request.pub"))
        print("PASS Apple PKCS12 identity import, Unicode password, wrong password and mismatched key rejection")
    }
}
