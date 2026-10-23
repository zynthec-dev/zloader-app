import Foundation

@main
struct WatchSigningTests {
    static func main() throws {
        let work = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let host = work.appendingPathComponent("Phone.app")
        let watch = host.appendingPathComponent("Watch/Watch.app")
        let phoneExtension = host.appendingPathComponent("PlugIns/Extension.appex")
        let watchExtension = watch.appendingPathComponent("PlugIns/Extension.appex")
        for url in [host, watch, phoneExtension, watchExtension] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        let components = try BundleSigningLayout.componentURLs(in: host)
        precondition(components.count == 4 && Set(components).count == 4)
        precondition(components.contains(phoneExtension.resolvingSymlinksInPath()))
        precondition(components.contains(watchExtension.resolvingSymlinksInPath()))

        let ids = ["example.phone": "example.phone.QA12345678",
                   "example.phone.watch": "example.phone.QA12345678.watch",
                   "example.phone.watch.extension": "example.phone.QA12345678.watch.extension"]
        let watchInfo: [String: Any] = ["CFBundleIdentifier": "example.phone.watch",
            "WKCompanionAppBundleIdentifier": "example.phone", "Unrelated": "example.phone"]
        let rewrittenWatch = try BundleSigningLayout.rewriting(watchInfo, identities: ids)
        precondition(rewrittenWatch["WKCompanionAppBundleIdentifier"] as? String == "example.phone.QA12345678")
        precondition(rewrittenWatch["Unrelated"] as? String == "example.phone")
        let cached: [String: any Sendable] = ["CFBundleIdentifier": "example.phone.OLDTEAM",
            "WKCompanionAppBundleIdentifier": "example.phone.OLDTEAM",
            "CFBundleDisplayName": "Custom name",
            "NSExtension": ["NSExtensionAttributes": ["WKAppBundleIdentifier": "example.phone.OLDTEAM.watch", "Unrelated": "preserved"]]]
        let metadata = BundleSigningLayout.preparationMetadata(cached)
        precondition(metadata["CFBundleIdentifier"] == nil && metadata["WKCompanionAppBundleIdentifier"] == nil)
        precondition(metadata["CFBundleDisplayName"] as? String == "Custom name")
        let cachedAttributes = (metadata["NSExtension"] as? [String: any Sendable])?["NSExtensionAttributes"] as? [String: any Sendable]
        precondition(cachedAttributes?["WKAppBundleIdentifier"] == nil)
        precondition(cachedAttributes?["Unrelated"] as? String == "preserved")
        let legacyInfo: [String: Any] = ["CFBundleIdentifier": "example.phone.watch.extension",
            "NSExtension": ["NSExtensionAttributes": ["WKAppBundleIdentifier": "example.phone.watch"]]]
        let legacy = try BundleSigningLayout.rewriting(legacyInfo, identities: ids)
        let attributes = (legacy["NSExtension"] as? [String: Any])?["NSExtensionAttributes"] as? [String: Any]
        precondition(attributes?["WKAppBundleIdentifier"] as? String == "example.phone.QA12345678.watch")
        let tasks: [String: Any] = ["CFBundleIdentifier": "example.phone",
            "BGTaskSchedulerPermittedIdentifiers": ["example.phone.refresh", "example.phone.QA12345678.refresh", "example.phone-other.refresh"]]
        let taskInfo = try BundleSigningLayout.rewriting(tasks, identities: ids)
        precondition(taskInfo["BGTaskSchedulerPermittedIdentifiers"] as? [String] ==
            ["example.phone.QA12345678.refresh", "example.phone-other.refresh"])
        do {
            _ = try BundleSigningLayout.rebasedIdentifier("example.phone-other.extension", from: "example.phone", to: "example.changed")
            fatalError("A sibling prefix must not become a child identity")
        } catch is CocoaError { }
        do {
            _ = try BundleSigningLayout.rewriting(["CFBundleIdentifier": "example.phone.watch",
                "WKCompanionAppBundleIdentifier": "missing.phone"], identities: ids)
            fatalError("An unresolved Watch companion must fail before signing")
        } catch is CocoaError { }

        if CommandLine.arguments.count > 1 {
            let root = URL(fileURLWithPath: CommandLine.arguments[1])
            let actual = try BundleSigningLayout.componentURLs(in: root)
            precondition(actual.count == 4, "The full Clawy fixture has four signing components")
            let identity = "de.renewitt.clawy.QA12345678"
            var mappings: [String: String] = [:]
            var plists: [[String: Any]] = []
            for component in actual {
                let data = try Data(contentsOf: component.appendingPathComponent("Info.plist"))
                let info = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
                let old = info["CFBundleIdentifier"] as! String
                mappings[old] = try BundleSigningLayout.rebasedIdentifier(old, from: "de.renewitt.clawy", to: identity)
                plists.append(info)
            }
            let transformed = try plists.map { try BundleSigningLayout.rewriting($0, identities: mappings) }
            let actualWatch = transformed.first { $0["WKCompanionAppBundleIdentifier"] != nil }!
            precondition(actualWatch["WKCompanionAppBundleIdentifier"] as? String == identity)
            precondition(actualWatch["CFBundleIdentifier"] as? String == identity + ".watchkitapp")
            precondition(transformed.allSatisfy { ($0["CFBundleIdentifier"] as! String).hasPrefix(identity) })
            print("PASS full Clawy IPA: four component identities and Watch companion rewritten consistently")
        }
        print("PASS modern and legacy Watch components, duplicate filenames, exact references and background tasks")
    }
}
