import Foundation
import SideSign

/// A fixed snapshot shared by one operation group. Contains no portal session.
struct ImportedSigningMaterial: @unchecked Sendable {
    let certificate: ALTCertificate
    let profiles: [ALTProvisioningProfile]
    let team: ALTTeam

    @MainActor static func load(_ identity: ImportedSigningIdentity) throws -> Self {
        guard let certificate = CertificateManager.shared.getLocalCertificate(serialNumber: identity.certificateSerial),
              let data = certificate.data, certificate.expiryDate > Date() else {
            throw OperationError.invalidParameters(NSLocalizedString("The imported certificate or private key is missing or expired.", comment: ""))
        }
        try PortablePKCS12.validate(certificate: data, key: certificate.privateKey)
        let profiles = try identity.profileIDs.map { id in
            guard let profile = ProfileManager.shared.getProfile(uuid: id) else {
                throw OperationError.invalidParameters(NSLocalizedString("An assigned provisioning profile is missing. Import it again.", comment: ""))
            }
            return profile
        }
        guard let first = profiles.first,
              profiles.allSatisfy({ $0.teamIdentifier == first.teamIdentifier &&
                  $0.certificates.contains { $0.rawDER == certificate.certificate.rawDER } }) else {
            throw OperationError.invalidParameters(NSLocalizedString("Every selected profile must belong to the same team and authorize this certificate.", comment: ""))
        }
        return Self(certificate: certificate, profiles: profiles,
            team: ALTTeam(identifier: first.teamIdentifier, name: first.teamName,
                          type: first.isFreeProvisioningProfile ? .free : .individual))
    }
}
