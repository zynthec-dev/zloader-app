import Foundation
import Security
import CryptoKit

/// App-owned keychain entries; private material never lives in UserDefaults.
enum LocalKeyMaterialStore {
    struct Item: Codable, Identifiable, Sendable {
        let id: String
        var name: String
        var created: Date
        let publicKey: Data
        var privateKey: Data?
        var request: Data?
        var fingerprint: String { SHA256.hash(data: PortablePKCS12.der(publicKey)).map { String(format: "%02x", $0) }.joined() }
    }
    private static let service = "com.zynthec.zLoader.local-key-material"
    static func list() throws -> [Item] {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: service,
            kSecReturnData: true, kSecMatchLimit: kSecMatchLimitAll] as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        return try (result as? [Data] ?? []).map { try JSONDecoder().decode(Item.self, from: $0) }.sorted { $0.created > $1.created }
    }
    static func save(_ item: Item) throws {
        let query = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: item.id] as CFDictionary
        let bytes = try JSONEncoder().encode(item)
        let status = SecItemUpdate(query, [kSecValueData: bytes, kSecAttrLabel: item.name] as CFDictionary)
        if status == errSecItemNotFound {
            let add = SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: item.id,
                kSecValueData: bytes, kSecAttrLabel: item.name, kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as CFDictionary, nil)
            guard add == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(add)) }
        } else if status != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    static func delete(_ item: Item) throws {
        let status = SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: item.id] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    static func createRequest(name: String, email: String, organization: String) throws -> Item {
        let generated = try PortablePKCS12.generateRequest(commonName: name, email: email, organization: organization)
        let item = Item(id: UUID().uuidString, name: name, created: Date(), publicKey: generated.publicKey, privateKey: generated.privateKey, request: generated.csr)
        try save(item)
        return item
    }
    static func matchingPrivateKey(certificate: Data) throws -> Data? {
        for item in try list() {
            if let key = item.privateKey, (try? PortablePKCS12.validate(certificate: certificate, key: key)) != nil { return key }
        }
        return nil
    }
    static func importKey(_ data: Data, name: String, isPrivate: Bool) throws {
        let publicKey = try isPrivate ? PortablePKCS12.publicKey(forPrivateKey: data) : PortablePKCS12.normalizedPublicKey(data)
        var item = Item(id: UUID().uuidString, name: name, created: Date(), publicKey: publicKey,
                        privateKey: isPrivate ? PortablePKCS12.pem(PortablePKCS12.rsaKeyDER(data), label: "RSA PRIVATE KEY") : nil, request: nil)
        if var existing = try list().first(where: { $0.publicKey == publicKey }) {
            if isPrivate { existing.privateKey = item.privateKey }
            item = existing
        }
        try save(item)
    }
}
