import Foundation
import CryptoKit

@main struct SourceIPAFileTests {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("fixture.ipa")
        let payload = Data([0x50, 0x4b, 0x03, 0x04]) + Data(repeating: 7, count: 2_000_000)
        try payload.write(to: file)
        let hash = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        try SourceIPAFile.validate(file: file, statusCode: 200, sha256: hash.uppercased())
        let unchanged = try Data(contentsOf: file)
        precondition(unchanged == payload)
        for (status, checksum) in [(403, hash), (503, hash), (200, "bad-hash")] {
            do { try SourceIPAFile.validate(file: file, statusCode: status, sha256: checksum); preconditionFailure("Must reject invalid download") } catch {}
        }
        try Data("<html>error</html>".utf8).write(to: file)
        do { try SourceIPAFile.validate(file: file, statusCode: 200, sha256: nil); preconditionFailure("Must reject HTML") } catch {}
        let name = SourceIPADownloadRequest(url: URL(string: "https://example.test/app.ipa")!, name: "../../App/name", version: "../1.0", sha256: nil).filename
        precondition(!name.contains("/") && !name.contains("\\") && name.hasSuffix(".ipa"))
        print("PASS raw IPA validation: HTTP failures, HTML rejection, streaming checksum, unchanged bytes and safe export filename")
    }
}
