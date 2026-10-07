import Foundation
import CryptoKit

@main struct TunnelPayloadTests {
    static func main() throws {
        let archive = Data("provider archive fixture".utf8)
        let digest = SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()
        let data = try PropertyListSerialization.data(fromPropertyList: ["version": "1", "build": "2", "sha256": digest], format: .binary, options: 0)
        let manifest = try TunnelPayloadManifest(data: data)
        try manifest.validate(archive: archive, version: "1", build: "2")
        for (bytes, version, build) in [(archive, "0", "2"), (archive, "1", "3"), (Data("tampered".utf8), "1", "2")] {
            do { try manifest.validate(archive: bytes, version: version, build: build); preconditionFailure("Incompatible payload accepted") }
            catch is TunnelPayloadManifest.Failure {}
        }
        let incomplete = try PropertyListSerialization.data(fromPropertyList: ["version": "1"], format: .xml, options: 0)
        do { _ = try TunnelPayloadManifest(data: incomplete); preconditionFailure("Incomplete metadata accepted") }
        catch TunnelPayloadManifest.Failure.invalidManifest {}
        print("PASS provider integrity, version/build binding, tamper rejection and incomplete metadata rejection")
    }
}
