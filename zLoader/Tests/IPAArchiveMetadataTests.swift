import Foundation

@main struct IPAArchiveMetadataTests {
    static func main() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: [
            "CFBundleIdentifier": "example.app", "CFBundleDisplayName": "Example",
            "CFBundleIcons": ["CFBundlePrimaryIcon": ["CFBundleIconFiles": ["AppIcon", "../../outside"]]]
        ], format: .binary, options: 0)
        let value = try IPAArchiveMetadata.read(data, path: "Payload/Example.app/Info.plist")
        precondition(value.name == "Example" && value.bundleID == "example.app")
        precondition(value.iconPaths == ["Payload/Example.app/AppIcon@3x.png", "Payload/Example.app/AppIcon@2x.png", "Payload/Example.app/AppIcon.png"])
        for path in ["Info.plist", "Payload/Example.app/PlugIns/Widget.appex/Info.plist", "__MACOSX/Payload/Example.app/Info.plist", "Payload//Example.app/Info.plist"] {
            precondition(!IPAArchiveMetadata.isAppInfoPlist(path))
            do { _ = try IPAArchiveMetadata.read(data, path: path); preconditionFailure("Must reject non-host metadata") } catch {}
        }
        for invalid in [Data("not a plist".utf8), Data(repeating: 0, count: Int(IPAArchiveMetadata.maximumEntrySize + 1)),
                        try PropertyListSerialization.data(fromPropertyList: ["CFBundleName": "Missing ID"], format: .xml, options: 0)] {
            do { _ = try IPAArchiveMetadata.read(invalid, path: "Payload/Example.app/Info.plist"); preconditionFailure("Must reject invalid metadata") } catch {}
        }
        print("PASS IPA library metadata: host only, bounded data, display name/ID and safe icon candidates; invalid and extension metadata rejected")
    }
}
