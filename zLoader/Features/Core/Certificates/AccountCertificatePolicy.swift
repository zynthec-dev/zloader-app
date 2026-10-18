import Foundation

/// Account signing depends on a current portal record and its actual private
/// key, not on which installer originally issued or imported the certificate.
enum AccountCertificatePolicy {
    static func canReuse(certificate: Data?, expiresAt: Date?, hasMatchingPrivateKey: Bool,
                         portalCertificates: [Data], now: Date = Date()) -> Bool {
        guard let certificate, !certificate.isEmpty, let expiresAt, expiresAt > now,
              hasMatchingPrivateKey else { return false }
        return portalCertificates.contains(certificate)
    }

    static func isIOSDevelopment(name: String, portalType: String?) -> Bool {
        if let type = portalType?.uppercased(), !type.isEmpty {
            return ["DEVELOPMENT", "IOS_DEVELOPMENT"].contains(type)
        }
        let name = name.lowercased()
        return name.contains("apple development") || name.contains("ios development") ||
            name.contains("ios app development") || name.contains("iphone developer")
    }
}
