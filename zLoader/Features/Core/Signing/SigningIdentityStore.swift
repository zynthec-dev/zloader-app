import Foundation
import Combine
import SideSign

enum SigningMethod: String {
    case appleAccount
    case importedCertificate
}

/// Non-secret references only. Certificate keys remain in CertificateManager's Keychain.
struct ImportedSigningIdentity: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var certificateSerial: String
    var profileIDs: [UUID]
}

@MainActor final class SigningIdentityStore: ObservableObject {
    static let shared = SigningIdentityStore()
    @Published private(set) var identities: [ImportedSigningIdentity]
    @Published private(set) var pipelineIdentityID: UUID?
    @Published private(set) var pipelineMethod: SigningMethod
    nonisolated static let pipelineMethodKey = "zLoader.pipelineSigningMethod"
    nonisolated static let pipelineIdentityKey = "zLoader.pipelineSigningIdentity"
    nonisolated static let pipelineTeamKey = "zLoader.pipelineSigningTeam"
    private let storageKey = "zLoader.signingIdentities"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let selectedID = defaults.string(forKey: Self.pipelineIdentityKey).flatMap(UUID.init(uuidString:))
        pipelineIdentityID = selectedID
        pipelineMethod = defaults.string(forKey: Self.pipelineMethodKey).flatMap(SigningMethod.init(rawValue:))
            ?? (selectedID == nil ? .appleAccount : .importedCertificate)
        identities = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([ImportedSigningIdentity].self, from: $0) } ?? []
    }

    func selectForAppOperations(_ id: UUID?) {
        pipelineMethod = id == nil ? .appleAccount : .importedCertificate
        defaults.set(pipelineMethod.rawValue, forKey: Self.pipelineMethodKey)
        pipelineIdentityID = id
        defaults.set(id?.uuidString, forKey: Self.pipelineIdentityKey)
        let team = id.flatMap { selected in identities.first { $0.id == selected } }
            .flatMap { $0.profileIDs.first }.flatMap { ProfileManager.shared.getProfile(uuid: $0)?.teamIdentifier }
        defaults.set(team, forKey: Self.pipelineTeamKey)
    }

    func selectMethodForAppOperations(_ method: SigningMethod) {
        if method == .appleAccount { selectForAppOperations(nil) }
        else if let id = pipelineIdentityID ?? identities.first?.id { selectForAppOperations(id) }
        else {
            pipelineMethod = .importedCertificate
            defaults.set(pipelineMethod.rawValue, forKey: Self.pipelineMethodKey)
        }
    }

    func selectedMaterial() throws -> ImportedSigningMaterial? {
        guard pipelineMethod == .importedCertificate else { return nil }
        guard let id = pipelineIdentityID else {
            throw OperationError.invalidParameters(String(localized: "Choose a certificate and matching provisioning profiles in Signing Identities first.", table: "AppActions"))
        }
        guard let identity = identities.first(where: { $0.id == id }) else {
            throw OperationError.invalidParameters(NSLocalizedString("The selected signing identity is missing. Choose an identity in Signing Identities.", comment: ""))
        }
        return try ImportedSigningMaterial.load(identity)
    }

    func save(_ identity: ImportedSigningIdentity) throws {
        guard !identity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let certificate = CertificateManager.shared.getLocalCertificate(serialNumber: identity.certificateSerial),
              let data = certificate.data else {
            throw OperationError.invalidParameters(NSLocalizedString("Choose a name and a certificate with its private key.", comment: ""))
        }
        try PortablePKCS12.validate(certificate: data, key: certificate.privateKey)
        guard !identity.profileIDs.isEmpty else {
            throw OperationError.invalidParameters(NSLocalizedString("Import at least one provisioning profile.", comment: ""))
        }
        for id in identity.profileIDs {
            guard let profile = ProfileManager.shared.getProfile(uuid: id),
                  profile.certificates.contains(where: { $0.rawDER == certificate.certificate.rawDER }) else {
                throw OperationError.invalidParameters(NSLocalizedString("Every selected profile must authorize this certificate.", comment: ""))
            }
        }
        var updated = identities.filter { $0.id != identity.id }
        updated.append(identity)
        try persist(updated)
        if pipelineIdentityID == identity.id || (pipelineIdentityID == nil && (pipelineMethod == .importedCertificate || !AuthManager.shared.isAuthenticated)) {
            selectForAppOperations(identity.id)
        }
    }

    func remove(_ identity: ImportedSigningIdentity) throws {
        // Removing this reference never revokes the certificate or deletes shared profiles.
        try persist(identities.filter { $0.id != identity.id })
    }

    private func persist(_ updated: [ImportedSigningIdentity]) throws {
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: storageKey)
        identities = updated
    }
}
