import Foundation
import Combine
import SideSign

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
    nonisolated static let pipelineIdentityKey = "zLoader.pipelineSigningIdentity"
    nonisolated static let pipelineTeamKey = "zLoader.pipelineSigningTeam"
    private let storageKey = "zLoader.signingIdentities"

    private init() {
        pipelineIdentityID = UserDefaults.standard.string(forKey: Self.pipelineIdentityKey).flatMap(UUID.init(uuidString:))
        identities = UserDefaults.standard.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([ImportedSigningIdentity].self, from: $0) } ?? []
    }

    func selectForAppOperations(_ id: UUID?) {
        pipelineIdentityID = id
        UserDefaults.standard.set(id?.uuidString, forKey: Self.pipelineIdentityKey)
        let team = id.flatMap { selected in identities.first { $0.id == selected } }
            .flatMap { $0.profileIDs.first }.flatMap { ProfileManager.shared.getProfile(uuid: $0)?.teamIdentifier }
        UserDefaults.standard.set(team, forKey: Self.pipelineTeamKey)
    }

    func selectedMaterial() throws -> ImportedSigningMaterial? {
        guard let id = pipelineIdentityID else { return nil }
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
        if pipelineIdentityID == identity.id || (pipelineIdentityID == nil && !AuthManager.shared.isAuthenticated) {
            selectForAppOperations(identity.id)
        }
    }

    func remove(_ identity: ImportedSigningIdentity) throws {
        // Removing this reference never revokes the certificate or deletes shared profiles.
        try persist(identities.filter { $0.id != identity.id })
    }

    private func persist(_ updated: [ImportedSigningIdentity]) throws {
        let data = try JSONEncoder().encode(updated)
        UserDefaults.standard.set(data, forKey: storageKey)
        identities = updated
    }
}
