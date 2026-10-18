import Foundation

@main struct AccountCertificatePolicyTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_000)
        let installer = Data([1, 2, 3]), foreign = Data([4, 5, 6])
        func usable(_ data: Data?, key: Bool = true, expiry: Date? = Date(timeIntervalSince1970: 2_000), portal: [Data] = [Data([1, 2, 3])]) -> Bool {
            AccountCertificatePolicy.canReuse(certificate: data, expiresAt: expiry,
                hasMatchingPrivateKey: key, portalCertificates: portal, now: now)
        }
        precondition(usable(installer), "A valid Side Installer identity with its matching key must be reusable")
        precondition(!usable(installer, key: false), "A public certificate alone cannot sign")
        precondition(!usable(installer, expiry: now))
        precondition(!usable(installer, expiry: nil))
        precondition(!usable(installer, portal: []), "A revoked certificate cannot bypass account provisioning")
        precondition(!usable(foreign), "A foreign active certificate cannot block own-team provisioning")
        precondition(!usable(nil) && !usable(Data()))
        precondition(AccountCertificatePolicy.isIOSDevelopment(name: "Apple Development: fixture", portalType: "DEVELOPMENT"))
        precondition(AccountCertificatePolicy.isIOSDevelopment(name: "iPhone Developer: fixture", portalType: nil))
        precondition(AccountCertificatePolicy.isIOSDevelopment(name: "Apple Development: fixture", portalType: nil))
        precondition(!AccountCertificatePolicy.isIOSDevelopment(name: "Apple Development: misleading", portalType: "DISTRIBUTION"))
        precondition(!AccountCertificatePolicy.isIOSDevelopment(name: "Mac Developer", portalType: "MAC_APP_DEVELOPMENT"))
        print("PASS account certificate reuse: installer identity with matching key, missing key, expired/revoked/foreign certificates; unified Apple Development replacement selection")
    }
}
