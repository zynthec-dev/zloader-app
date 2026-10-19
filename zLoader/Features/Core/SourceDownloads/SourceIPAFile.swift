import Foundation
import CryptoKit

struct SourceIPADownloadRequest: Sendable {
    let url: URL
    let name: String
    let version: String
    let sha256: String?

    var filename: String {
        func clean(_ value: String) -> String {
            String(value.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || "-_.".unicodeScalars.contains($0) ? String($0) : "_" }.joined().prefix(90))
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
        return (clean(name).isEmpty ? "App" : clean(name)) + "-" + (clean(version).isEmpty ? "latest" : clean(version)) + ".ipa"
    }
}

enum SourceIPAFile {
    enum Failure: LocalizedError {
        case http(Int), invalidArchive, checksum
        var errorDescription: String? {
            switch self {
            case .http(let code): return String(format: NSLocalizedString("IPA download failed (HTTP %d).", comment: ""), code)
            case .invalidArchive: return NSLocalizedString("The server did not return an IPA archive.", comment: "")
            case .checksum: return NSLocalizedString("The downloaded IPA does not match the source checksum.", comment: "")
            }
        }
    }

    static func validate(file: URL, statusCode: Int, sha256: String?) throws {
        try Task.checkCancellation()
        guard (200..<300).contains(statusCode) else { throw Failure.http(statusCode) }
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        guard try input.read(upToCount: 4) == Data([0x50, 0x4b, 0x03, 0x04]) else { throw Failure.invalidArchive }
        if let sha256, !sha256.isEmpty {
            try input.seek(toOffset: 0)
            var digest = SHA256()
            while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty {
                try Task.checkCancellation()
                digest.update(data: chunk)
            }
            let actual = digest.finalize().map { String(format: "%02x", $0) }.joined()
            guard actual.caseInsensitiveCompare(sha256) == .orderedSame else { throw Failure.checksum }
        }
    }

    static func download(_ request: SourceIPADownloadRequest) async throws -> URL {
        let (temporary, response) = try await URLSession.shared.download(from: request.url)
        // Hashing large archives and file copying must not run on the UI actor.
        let worker = Task.detached {
            defer { try? FileManager.default.removeItem(at: temporary) }
            try validate(file: temporary, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, sha256: request.sha256)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SourceIPA-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            do {
                try Task.checkCancellation()
                let file = folder.appendingPathComponent(request.filename)
                try FileManager.default.moveItem(at: temporary, to: file)
                return file
            } catch {
                try? FileManager.default.removeItem(at: folder)
                throw error
            }
        }
        return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }
}
