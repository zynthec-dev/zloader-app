import Foundation

@main
struct ExtensionKitSigningTests {
    static func info(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url.appendingPathComponent("Info.plist"))
        return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
    }

    static func write(_ info: [String: Any], at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0)
        try data.write(to: url.appendingPathComponent("Info.plist"), options: .atomic)
    }

    static func rewrite(_ root: URL, original: String, resolved: String) throws {
        let components = try BundleSigningLayout.componentURLs(in: root)
        let metadata = try components.map { try info(at: $0) }
        let identities = try Dictionary(uniqueKeysWithValues: metadata.map { info in
            let id = info["CFBundleIdentifier"] as! String
            return (id, try BundleSigningLayout.rebasedIdentifier(id, from: original, to: resolved))
        })
        for (url, info) in zip(components, metadata) {
            try write(BundleSigningLayout.rewriting(info, identities: identities), at: url)
        }
        try BundleSigningLayout.validateIdentifiers(in: root)
        for url in components.dropFirst() {
            let id = try info(at: url)["CFBundleIdentifier"] as! String
            precondition(id.hasPrefix(resolved + "."))
        }
    }

    static func main() throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: work) }
        let host = work.appendingPathComponent("UTM.app")
        let helper = host.appendingPathComponent("Extensions/iOSHelper.appex")
        let classic = host.appendingPathComponent("PlugIns/iOSHelper.appex")
        let nested = helper.appendingPathComponent("Extensions/Nested.APPEX")
        let ignored = host.appendingPathComponent("Resources/Extensions/Decoy.appex")
        let original = "com.utmapp.UTM"
        let target = original + ".QA12345678"
        let extensionAttributes: [String: Any] = ["EXExtensionPointIdentifier": original + ".qemu-helper"]
        try write(["CFBundleIdentifier": original], at: host)
        try write(["CFBundleIdentifier": original + ".iOSHelper", "EXAppExtensionAttributes": extensionAttributes], at: helper)
        try write(["CFBundleIdentifier": original + ".classic"], at: classic)
        try write(["CFBundleIdentifier": original + ".iOSHelper.nested"], at: nested)
        try write(["CFBundleIdentifier": "unrelated.decoy"], at: ignored)
        let components = try BundleSigningLayout.componentURLs(in: host)
        precondition(components.count == 4 && components.first == host.resolvingSymlinksInPath())
        let directExtensions = try BundleSigningLayout.extensionURLs(in: host)
        precondition(Set(directExtensions) == Set([helper,classic].map { $0.resolvingSymlinksInPath() }))
        try BundleSigningLayout.validateIdentifiers(in: host)
        // Reproduce the screenshot: the host changes while its ExtensionKit child
        // retains com.utmapp.UTM.iOSHelper. Reject it before signing/installing.
        try write(["CFBundleIdentifier": target], at: host)
        do {
            try BundleSigningLayout.validateIdentifiers(in: host)
            preconditionFailure("An old child identifier was accepted under a re-signed host")
        } catch let error as CocoaError {
            precondition(error.code == .propertyListReadCorrupt)
        }
        try write(["CFBundleIdentifier": original], at: host)
        try rewrite(host, original: original, resolved: target)
        let updatedHelper = try info(at: helper)
        precondition(updatedHelper["CFBundleIdentifier"] as? String == target + ".iOSHelper")
        // Extension point identifiers are protocol names, not app identities.
        let updatedAttributes = updatedHelper["EXAppExtensionAttributes"] as! [String: String]
        precondition(updatedAttributes["EXExtensionPointIdentifier"] == original + ".qemu-helper")
        // Aliases inside the host are deduplicated; external .appex links fail.
        try fm.createSymbolicLink(at: host.appendingPathComponent("PlugIns/Alias.appex"), withDestinationURL: helper)
        let aliasedComponents = try BundleSigningLayout.componentURLs(in: host)
        precondition(aliasedComponents.count == 4)
        let outside = work.appendingPathComponent("Outside.appex")
        try write(["CFBundleIdentifier":"outside.helper"], at: outside)
        let escape = host.appendingPathComponent("Extensions/Escape.appex")
        try fm.createSymbolicLink(at: escape, withDestinationURL: outside)
        do {
            _ = try BundleSigningLayout.componentURLs(in: host)
            preconditionFailure("An external extension symlink was accepted")
        } catch let error as CocoaError { precondition(error.code == .fileReadNoPermission) }
        print("PASS ExtensionKit/classic/nested discovery; duplicate filenames and symlink bounds; screenshot mismatch rejected; whole-graph IDs rewritten; extension point preserved")

        if CommandLine.arguments.count > 1 {
            let root = URL(fileURLWithPath: CommandLine.arguments[1])
            let actual = try BundleSigningLayout.componentURLs(in: root)
            precondition(actual.count == 2, "Official UTM fixture must contain the host and iOSHelper")
            let before = try info(at: root)
            let originalID = before["CFBundleIdentifier"] as! String
            precondition(originalID == original)
            precondition(actual[1].path.contains("/Extensions/iOSHelper.appex"))
            try rewrite(root, original: originalID, resolved: target)
            let helperInfo = try info(at: actual[1])
            precondition(helperInfo["CFBundleIdentifier"] as? String == target + ".iOSHelper")
            precondition((helperInfo["EXAppExtensionAttributes"] as? [String: String])?["EXExtensionPointIdentifier"] == original + ".qemu-helper")
            print("PASS official UTM IPA: actual ExtensionKit iOSHelper discovered and assigned the re-signed host prefix without removing the helper")
        }
    }
}
