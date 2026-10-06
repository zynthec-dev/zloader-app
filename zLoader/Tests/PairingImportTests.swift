import Foundation
import MinimuxerCommon

// Synthetic records only. Run against the actual PairingFileManager and parser.
private let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
extension FileManager { var documentsDirectory: URL { testDirectory } }
enum AppConstants {
    enum Pairing {
        static let supportedExtensions = ["plist", "mobiledevicepairing"]
        static let lockdownPairingFileName = "PairingFile_Lockdown.plist"
        static let remotePairingFileName = "PairingFile_RemoteRP.plist"
        static let legacyPairingFileName = "ALTPairingFile.mobiledevicepairing"
    }
}
extension UserDefaults {
    var isPairingReset: Bool {
        get { bool(forKey: "zloader.test.reset") }
        set { set(newValue, forKey: "zloader.test.reset") }
    }
    var activePairingProtocol: PairingProtocol? {
        get { string(forKey: "zloader.test.active").flatMap(PairingProtocol.init(rawValue:)) }
        set { set(newValue?.rawValue, forKey: "zloader.test.active") }
    }
    var preferredPairingProtocol: PairingProtocol? {
        get { string(forKey: "zloader.test.preferred").flatMap(PairingProtocol.init(rawValue:)) }
        set { set(newValue?.rawValue, forKey: "zloader.test.preferred") }
    }
}
func minimuxerPairingProtocol() -> PairingProtocol { .rppairing }
func debugLog(_ text: String) {}

@main struct PairingImportTests {
    static func main() throws {
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: testDirectory)
            for key in ["reset", "active", "preferred"] { UserDefaults.standard.removeObject(forKey: "zloader.test." + key) }
        }
        let manager = PairingFileManager.shared
        manager.resetAllPairingFiles()
        let remote: [String: Any] = ["identifier": "synthetic-host", "private_key": Data([1]), "public_key": Data([2])]
        var combined = remote
        for key in ["WiFiMACAddress", "SystemBUID", "RootPrivateKey", "HostPrivateKey", "HostID", "RootCertificate", "UDID", "EscrowBag", "HostCertificate", "DeviceCertificate"] {
            combined[key] = Data([3])
        }
        let incoming = testDirectory.appendingPathComponent("pairingFile.plist")
        try PropertyListSerialization.data(fromPropertyList: combined, format: .binary, options: 0).write(to: incoming)
        manager.importTransferredPairingFiles()
        precondition(manager.hasPairingFile(for: .lockdown) && manager.hasPairingFile(for: .rppairing))
        precondition(manager.persistedActiveProtocol == .rppairing)
        precondition(!FileManager.default.fileExists(atPath: incoming.path))
        manager.preferredProtocol = .lockdown
        let selectedLockdown = try manager.parse(content: manager.fetchPairingFile()!).mode
        precondition(selectedLockdown == .lockdown)
        manager.resetAllPairingFiles()
        try PropertyListSerialization.data(fromPropertyList: remote, format: .xml, options: 0).write(to: incoming)
        manager.importTransferredPairingFiles()
        precondition(manager.hasPairingFile() && !manager.hasPairingFile(for: .lockdown))
        let selectedRemote = try manager.parse(content: manager.fetchPairingFile()!).mode
        precondition(selectedRemote == .rppairing)
        manager.resetAllPairingFiles()
        try Data("invalid pairing input".utf8).write(to: incoming)
        manager.importTransferredPairingFiles()
        precondition(FileManager.default.fileExists(atPath: incoming.path))
        precondition(!manager.hasPairingFile())
        print("PASS combined/binary iLoader import retains both protocols, protocol selection, remote-only fallback and invalid-input retention")
    }
}
