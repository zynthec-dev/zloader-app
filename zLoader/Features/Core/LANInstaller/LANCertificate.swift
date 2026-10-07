import Foundation
import Security
import CommonCrypto

/// Device-local CA, kept in Keychain. Only its public certificate leaves this device.
enum LANCertificate {
    struct Authority: Sendable {
        let certificate: Data
        let privateKey: Data
        let subject: Data
    }
    struct ServerIdentity {
        let identity: SecIdentity
        let certificate: SecCertificate
        let key: SecKey
        func remove() {
            SecItemDelete([kSecClass: kSecClassCertificate, kSecValueRef: certificate] as CFDictionary)
            SecItemDelete([kSecClass: kSecClassKey, kSecValueRef: key] as CFDictionary)
        }
    }
    enum Failure: LocalizedError {
        case crypto, keychain(OSStatus)
        var errorDescription: String? {
            switch self {
            case .crypto: return NSLocalizedString("Could not create the local HTTPS certificate.", comment: "")
            case .keychain(let status): return "Keychain: \(status)"
            }
        }
    }
    static func authority(name: String) throws -> Authority {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.zynthec.zLoader.LANAuthority", kSecAttrAccount: "CA"]
        var item: CFTypeRef?
        let status = SecItemCopyMatching((query.merging([kSecReturnData: true]) { _, new in new }) as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data,
           let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Data],
           let cert = values["certificate"], let key = values["key"], let subject = values["subject"] {
            return Authority(certificate: cert, privateKey: key, subject: subject)
        }
        guard status == errSecItemNotFound else { throw Failure.keychain(status) }
        let authority = try createAuthority(name: name)
        let cert = authority.certificate
        let bytes = authority.privateKey
        let subject = authority.subject
        let data = try PropertyListSerialization.data(fromPropertyList: ["certificate": cert, "key": bytes as Data, "subject": subject], format: .binary, options: 0)
        let add = query.merging([kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]) { _, new in new }
        let added = SecItemAdd(add as CFDictionary, nil)
        guard added == errSecSuccess else { throw Failure.keychain(added) }
        return authority
    }
    static func createAuthority(name: String) throws -> Authority {
        let key = try makeKey()
        let subject = distinguishedName(name)
        let cert = try certificate(subject: subject, issuer: subject, publicKey: key,
            signer: key, extensions: [ext("2.5.29.19", seq(Data([0x01, 0x01, 0xff])), critical: true),
                                     ext("2.5.29.15", tlv(0x03, Data([1, 6])), critical: true)], days: 1825)
        guard let bytes = SecKeyCopyExternalRepresentation(key, nil) else { throw Failure.crypto }
        return Authority(certificate: cert, privateKey: bytes as Data, subject: subject)
    }
    static func identity(authority: Authority, ip: String, name: String) throws -> ServerIdentity {
        guard let signer = SecKeyCreateWithData(authority.privateKey as CFData,
            [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate] as CFDictionary, nil) else { throw Failure.crypto }
        let key = try makeKey()
        let octets = ip.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { throw Failure.crypto }
        let leaf = try certificate(subject: distinguishedName(name), issuer: authority.subject, publicKey: key, signer: signer,
            extensions: [ext("2.5.29.19", seq(Data()), critical: true),
                         ext("2.5.29.15", tlv(0x03, Data([5, 0xa0])), critical: true),
                         ext("2.5.29.37", seq(oid("1.3.6.1.5.5.7.3.1"))),
                         ext("2.5.29.17", seq(tlv(0x87, Data(octets))))], days: 30)
        guard let rawKey = SecKeyCopyExternalRepresentation(key, nil) else { throw Failure.crypto }
        let password = UUID().uuidString
        let p12 = try PortablePKCS12.build(certificate: leaf, key: rawKey as Data, password: password, name: name)
        var items: CFArray?
        var options: [CFString: Any] = [kSecImportExportPassphrase: password]
        #if os(macOS)
        options[kSecImportToMemoryOnly] = true
        #endif
        let status = SecPKCS12Import(p12 as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess, let first = (items as? [[String: Any]])?.first,
              let value = first[kSecImportItemIdentity as String] else { throw Failure.keychain(status) }
        let identity = value as! SecIdentity
        var certificate: SecCertificate?
        var privateKey: SecKey?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
              SecIdentityCopyPrivateKey(identity, &privateKey) == errSecSuccess,
              let certificate, let privateKey else { throw Failure.crypto }
        return ServerIdentity(identity: identity, certificate: certificate, key: privateKey)
    }
    static func trustProfile(authority: Authority, name: String) throws -> Data {
        let id = UUID().uuidString
        return try PropertyListSerialization.data(fromPropertyList: [
            "PayloadType": "Configuration", "PayloadVersion": 1,
            "PayloadIdentifier": "com.zynthec.zLoader.lan." + id, "PayloadUUID": id,
            "PayloadDisplayName": name,
            "PayloadDescription": "Local HTTPS trust for zLoader IPA sharing. This certificate does not authorize app signing.",
            "PayloadContent": [["PayloadType": "com.apple.security.root", "PayloadVersion": 1,
                "PayloadIdentifier": "com.zynthec.zLoader.lan.ca." + id, "PayloadUUID": UUID().uuidString,
                "PayloadDisplayName": name, "PayloadContent": authority.certificate]]
        ], format: .xml, options: 0)
    }
    private static func makeKey() throws -> SecKey {
        guard let key = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048] as CFDictionary, nil) else { throw Failure.crypto }
        return key
    }
    private static func certificate(subject: Data, issuer: Data, publicKey: SecKey, signer: SecKey, extensions: [Data], days: Int) throws -> Data {
        guard let pub = SecKeyCopyPublicKey(publicKey), let bytes = SecKeyCopyExternalRepresentation(pub, nil) else { throw Failure.crypto }
        let algorithm = seq(oid("1.2.840.113549.1.1.11") + tlv(0x05, Data()))
        let publicAlgorithm = seq(oid("1.2.840.113549.1.1.1") + tlv(0x05, Data()))
        var serial = withUnsafeBytes(of: UUID().uuid) { Data($0) }
        while serial.count > 1 && serial.first == 0 { serial.removeFirst() }
        if (serial.first ?? 0) & 0x80 != 0 { serial.insert(0, at: 0) }
        let identifiers = [ext("2.5.29.14", tlv(0x04, try keyIdentifier(publicKey))),
                           ext("2.5.29.35", seq(tlv(0x80, try keyIdentifier(signer))))]
        let tbs = seq(tlv(0xa0, tlv(0x02, Data([2]))) + tlv(0x02, serial) + algorithm + issuer +
            seq(time(Date().addingTimeInterval(-300)) + time(Date().addingTimeInterval(Double(days) * 86400))) + subject +
            seq(publicAlgorithm + tlv(0x03, Data([0]) + (bytes as Data))) + tlv(0xa3, seq((extensions + identifiers).reduce(Data(), +))))
        guard let signature = SecKeyCreateSignature(signer, .rsaSignatureMessagePKCS1v15SHA256, tbs as CFData, nil) else { throw Failure.crypto }
        return seq(tbs + algorithm + tlv(0x03, Data([0]) + (signature as Data)))
    }
    private static func keyIdentifier(_ key: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(key),
              let bytes = SecKeyCopyExternalRepresentation(publicKey, nil) else { throw Failure.crypto }
        let data = bytes as Data
        var digest = Data(count: Int(CC_SHA1_DIGEST_LENGTH))
        _ = digest.withUnsafeMutableBytes { output in
            data.withUnsafeBytes { input in
                CC_SHA1(input.baseAddress, CC_LONG(data.count), output.baseAddress?.assumingMemoryBound(to: UInt8.self))
            }
        }
        return digest
    }
    private static func distinguishedName(_ name: String) -> Data { seq(tlv(0x31, seq(oid("2.5.4.3") + tlv(0x0c, Data(name.utf8))))) }
    private static func time(_ date: Date) -> Data {
        let format = DateFormatter(); format.locale = Locale(identifier: "en_US_POSIX"); format.timeZone = TimeZone(secondsFromGMT: 0); format.dateFormat = "yyMMddHHmmss'Z'"
        return tlv(0x17, Data(format.string(from: date).utf8))
    }
    private static func ext(_ id: String, _ value: Data, critical: Bool = false) -> Data { seq(oid(id) + (critical ? Data([0x01, 0x01, 0xff]) : Data()) + tlv(0x04, value)) }
    private static func seq(_ data: Data) -> Data { tlv(0x30, data) }
    private static func tlv(_ tag: UInt8, _ data: Data) -> Data {
        var length = data.count; var bytes = [UInt8]()
        repeat { bytes.insert(UInt8(length & 255), at: 0); length >>= 8 } while length > 0
        return Data([tag]) + (data.count < 128 ? Data([UInt8(data.count)]) : Data([0x80 | UInt8(bytes.count)] + bytes)) + data
    }
    private static func oid(_ string: String) -> Data {
        let parts = string.split(separator: ".").map { Int($0)! }; var data = Data([UInt8(parts[0] * 40 + parts[1])])
        for part in parts.dropFirst(2) {
            var value = part; var bytes = [UInt8(value & 127)]; value >>= 7
            while value > 0 { bytes.insert(UInt8(value & 127) | 128, at: 0); value >>= 7 }
            data.append(contentsOf: bytes)
        }
        return tlv(0x06, data)
    }
}
