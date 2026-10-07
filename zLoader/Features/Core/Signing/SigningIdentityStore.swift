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
    private let storageKey = "zLoader.signingIdentities"

    private init() {
        identities = UserDefaults.standard.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([ImportedSigningIdentity].self, from: $0) } ?? []
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
