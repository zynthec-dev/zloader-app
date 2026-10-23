import Foundation

// Standalone harness: the production server manager runs against temporary
// files; no app keychain, Apple credentials or real remote servers are used.
enum AppConstants {
    enum Anisette {
        enum Servers {
            static let defaultSource = "https://catalog.invalid/servers.json"
            static let defaultServerURL = "https://mac-ani.jkcoxson.com"
            static let connectivityCheckURL = URL(string: "https://apple.invalid")!
        }
    }
}
struct Server: Codable { let name: String; let address: String }
struct AnisetteServerData: Codable { let servers: [Server] }
func debugLog(_ message: String) {}

enum TestStorage {
    static let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}
extension FileManager {
    var documentsDirectory: URL { TestStorage.directory }
    var applicationSupportDirectory: URL { TestStorage.directory }
}
extension UserDefaults {
    var useOnDeviceAnisette: Bool {
        get { bool(forKey: #function) }
        set { set(newValue, forKey: #function) }
    }
    var disableAnisetteRotation: Bool {
        get { bool(forKey: #function) }
        set { set(newValue, forKey: #function) }
    }
    var menuAnisetteURL: String {
        get { string(forKey: #function) ?? AppConstants.Anisette.Servers.defaultServerURL }
        set { set(newValue, forKey: #function) }
    }
    var menuAnisetteList: String {
        get { string(forKey: #function) ?? "" }
        set { set(newValue, forKey: #function) }
    }
}

@main
struct AnisetteServerMigrationTests {
    static func main() async throws {
        let defaults = UserDefaults.standard
        // A fresh isolated preferences domain is only visible to this process.
        defaults.setVolatileDomain([:], forName: UserDefaults.argumentDomain)
        for key in ["useOnDeviceAnisette", "disableAnisetteRotation", "menuAnisetteURL", "zLoader.macAnisetteMigration.v1"] {
            defaults.removeObject(forKey: key)
        }
        try FileManager.default.createDirectory(at: TestStorage.directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: TestStorage.directory) }
        let manager = AnisetteServersManager.shared
        defaults.useOnDeviceAnisette = true
        defaults.menuAnisetteURL = "https://old.invalid"
        await manager.prepareMacAnisetteIfNeeded()
        precondition(!defaults.useOnDeviceAnisette && defaults.disableAnisetteRotation)
        precondition(defaults.menuAnisetteURL == AppConstants.Anisette.Servers.defaultServerURL)
        let fallback = await manager.getActiveServerURLs()
        precondition(fallback == [AppConstants.Anisette.Servers.defaultServerURL])
        // Subsequent launches retain deliberate changes made after migration.
        defaults.useOnDeviceAnisette = true
        defaults.menuAnisetteURL = "https://custom.invalid"
        defaults.disableAnisetteRotation = false
        await manager.prepareMacAnisetteIfNeeded()
        precondition(defaults.useOnDeviceAnisette && !defaults.disableAnisetteRotation)
        precondition(defaults.menuAnisetteURL == "https://custom.invalid")
        let imported = Data(#"{"servers":[{"name":"Private","address":"https://custom.invalid"}]}"#.utf8)
        _ = try await manager.importFromData(data: imported, filename: "custom.json")
        let catalog = await manager.loadLocalServers()
        precondition(catalog.count == 2 && catalog.last?.name == "Private")
        let exported = await manager.exportCatalogData()!
        let exportedCatalog = try JSONDecoder().decode(AnisetteServerData.self, from: exported)
        precondition(exportedCatalog.servers.count == 2)
        var hidden = catalog
        hidden[0].isHidden = true
        await manager.saveLocalServers(hidden)
        let active = await manager.getActiveServerURLs()
        precondition(active == ["https://custom.invalid"])
        let saved = await manager.loadLocalServers()
        precondition(saved.count == 2 && saved[0].isHidden)
        print("PASS existing ODA migration once; bundled Mac server without network/catalog; custom list preservation; explicit opt-out and hidden state")
    }
}
