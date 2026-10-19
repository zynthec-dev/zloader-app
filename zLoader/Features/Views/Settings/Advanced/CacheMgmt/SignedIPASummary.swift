import Foundation
import SideSign

struct SignedIPASummary: Sendable {
    let name: String
    let bundleID: String
    let iconData: Data?

    static func read(_ url: URL) throws -> Self {
        let archive = try Archive.Reader.open(at: url)
        let entries = try archive.entries()
        guard let info = entries.first(where: { IPAArchiveMetadata.isAppInfoPlist($0.filename) }),
              info.uncompressedSize <= IPAArchiveMetadata.maximumEntrySize else {
            throw CocoaError(.fileReadCorruptFile)
        }
        func data(for name: String) throws -> Data? {
            try archive.goToFirstFile()
            repeat {
                try Task.checkCancellation()
                if try archive.currentFilename() == name {
                    let entry = try archive.currentEntry()
                    guard entry.uncompressedSize >= 0, entry.uncompressedSize <= IPAArchiveMetadata.maximumEntrySize,
                          entry.compressedSize >= 0, entry.compressedSize <= IPAArchiveMetadata.maximumEntrySize else { return nil }
                    return try archive.readCurrentFile()
                }
            } while archive.goToNextFile()
            return nil
        }
        guard let plist = try data(for: info.filename) else { throw CocoaError(.fileReadCorruptFile) }
        let metadata = try IPAArchiveMetadata.read(plist, path: info.filename)
        let available = Set(entries.map(\.filename))
        let fallback = entries.first { $0.filename.hasPrefix(metadata.appPath + "AppIcon") &&
            !$0.filename.dropFirst(metadata.appPath.count).contains("/") && $0.filename.hasSuffix(".png") }?.filename
        let icon = metadata.iconPaths.first(where: available.contains) ?? fallback
        return Self(name: metadata.name, bundleID: metadata.bundleID, iconData: try icon.flatMap { try data(for: $0) })
    }
}
