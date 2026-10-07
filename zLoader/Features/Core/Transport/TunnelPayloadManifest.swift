import Foundation
import CryptoKit

/// Integrity/version binding for inert provider data, not an Apple authorization.
struct TunnelPayloadManifest {
    let version: String
    let build: String
    let sha256: String

    init(data: Data) throws {
        guard let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
              let version = values["version"], let build = values["build"], let sha256 = values["sha256"],
              !version.isEmpty, !build.isEmpty, sha256.count == 64 else {
            throw Failure.invalidManifest
        }
        self.version = version
        self.build = build
        self.sha256 = sha256
    }

    func validate(archive: Data, version: String?, build: String?) throws {
        guard self.version == version, self.build == build else { throw Failure.versionMismatch }
        let actual = SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()
        guard actual == sha256 else { throw Failure.corruptArchive }
    }

    enum Failure: Error { case invalidManifest, versionMismatch, corruptArchive }
}
