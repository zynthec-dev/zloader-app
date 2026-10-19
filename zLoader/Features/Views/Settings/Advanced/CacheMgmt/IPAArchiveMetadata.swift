import Foundation

/// Lightweight library metadata; signing/profile inspection remains an explicit action.
struct IPAArchiveMetadata: Sendable {
    let name: String
    let bundleID: String
    let appPath: String
    let iconPaths: [String]
    static let maximumEntrySize: Int64 = 8 * 1024 * 1024

    static func isAppInfoPlist(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.count == 3 && parts[0] == "Payload" && parts[1].hasSuffix(".app") && parts[2] == "Info.plist"
    }

    static func read(_ data: Data, path: String) throws -> Self {
        guard isAppInfoPlist(path), data.count <= maximumEntrySize,
              let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = info["CFBundleIdentifier"] as? String, !bundleID.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let appPath = String(path.dropLast("Info.plist".count))
        let primary = (info["CFBundleIcons"] as? [String: Any])?["CFBundlePrimaryIcon"] as? [String: Any]
        let icons = (primary?["CFBundleIconFiles"] as? [String] ?? []) + (info["CFBundleIconFiles"] as? [String] ?? [])
        let iconPaths = icons.reversed().flatMap { icon -> [String] in
            guard !icon.contains("/"), !icon.contains("\\"), !icon.contains("..") else { return [] }
            let stem = icon.hasSuffix(".png") ? String(icon.dropLast(4)) : icon
            return ["@3x.png", "@2x.png", ".png"].map { appPath + stem + $0 }
        }
        return Self(name: info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? bundleID,
                    bundleID: bundleID, appPath: appPath, iconPaths: iconPaths)
    }
}
