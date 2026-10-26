import Foundation

// Store-level fixtures carry no real credentials. Crypto/profile authorization
// is covered separately by the managed-signing and PKCS#12 regression suites.
struct TestCertificate { let rawDER: Data }
struct ALTCertificate {
    let data: Data? = Data([1])
    let privateKey = Data([2])
    let certificate = TestCertificate(rawDER: Data([1]))
}
struct TestProfile {
    let teamIdentifier = "TEST-TEAM"
    let certificates = [TestCertificate(rawDER: Data([1]))]
}
final class CertificateManager {
    static let shared = CertificateManager()
    func getLocalCertificate(serialNumber: String) -> ALTCertificate? { serialNumber == "fixture" ? ALTCertificate() : nil }
}
final class ProfileManager {
    static let shared = ProfileManager()
    var validID = UUID()
    func getProfile(uuid: UUID) -> TestProfile? { uuid == validID ? TestProfile() : nil }
}
enum PortablePKCS12 { static func validate(certificate: Data, key: Data) throws {} }
final class AuthManager {
    static let shared = AuthManager()
    var isAuthenticated = false
}
enum OperationError: Error { case invalidParameters(String) }
struct ImportedSigningMaterial {
    static func load(_ identity: ImportedSigningIdentity) throws -> Self { Self() }
}

@main struct ImportedSigningSelectionTests {
    @MainActor static func main() throws {
        let suite = "zLoader.ImportedSigningSelectionTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SigningIdentityStore(defaults: defaults)
        assert(store.pipelineMethod == .appleAccount)
        store.selectMethodForAppOperations(.importedCertificate)
        assert(store.pipelineMethod == .importedCertificate && store.pipelineIdentityID == nil)
        do {
            _ = try store.selectedMaterial()
            fatalError("An unconfigured imported method must not fall through to Apple signing")
        } catch OperationError.invalidParameters { }
        assert(SigningIdentityStore(defaults: defaults).pipelineMethod == .importedCertificate)

        AuthManager.shared.isAuthenticated = true
        let identity = ImportedSigningIdentity(name: "Wildcard fixture", certificateSerial: "fixture", profileIDs: [ProfileManager.shared.validID])
        try store.save(identity)
        assert(store.pipelineIdentityID == identity.id && store.pipelineMethod == .importedCertificate)
        let imported = try store.selectedMaterial()
        assert(imported != nil)
        assert(defaults.string(forKey: SigningIdentityStore.pipelineTeamKey) == "TEST-TEAM")
        try store.remove(identity)
        do {
            _ = try store.selectedMaterial()
            fatalError("Removing an imported identity must never select Apple Account implicitly")
        } catch OperationError.invalidParameters { }
        store.selectMethodForAppOperations(.appleAccount)
        let apple = try store.selectedMaterial()
        assert(store.pipelineIdentityID == nil && apple == nil)

        defaults.removeObject(forKey: SigningIdentityStore.pipelineMethodKey)
        defaults.set(identity.id.uuidString, forKey: SigningIdentityStore.pipelineIdentityKey)
        assert(SigningIdentityStore(defaults: defaults).pipelineMethod == .importedCertificate)
        print("PASS imported method availability, persistence, saved identity activation, fail-closed removal and legacy selection migration")
    }
}
