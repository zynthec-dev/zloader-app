import Foundation
import Security
import CommonCrypto

/// Password-protected PKCS#12 with PBES2/AES-256, matching bag IDs and a MAC.
/// Uses platform crypto; interoperability is tested with Apple and OpenSSL.
enum PortablePKCS12 {
    enum Failure: LocalizedError {
        case invalidKey, keyMismatch, crypto(Int32), invalidPassword
        var errorDescription: String? {
            switch self {
            case .invalidKey: return "Invalid RSA private key or certificate."
            case .keyMismatch: return "The private key does not match this certificate."
            case .crypto(let status): return "Certificate encryption failed (\(status))."
            case .invalidPassword: return "Use a nonempty password without a null character."
            }
        }
    }
    static func der(_ data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8), text.contains("-----BEGIN") else { return data }
        let base64 = text.components(separatedBy: .newlines).filter { !$0.hasPrefix("-----") }.joined()
        return Data(base64Encoded: base64, options: .ignoreUnknownCharacters) ?? Data()
    }
    static func pem(_ data: Data, label: String) -> Data {
        Data(("-----BEGIN \(label)-----\n" + data.base64EncodedString(options: .lineLength64Characters) + "\n-----END \(label)-----\n").utf8)
    }
    static func rsaKeyDER(_ raw: Data) -> Data {
        let data = der(raw)
        // PKCS#8: version, AlgorithmIdentifier, OCTET STRING containing PKCS#1.
        var offset = 0
        guard let outer = read(data, offset: &offset), outer.0 == 0x30 else { return data }
        var inner = 0
        _ = read(outer.1, offset: &inner)
        if let algorithm = read(outer.1, offset: &inner), algorithm.0 == 0x30,
           let key = read(outer.1, offset: &inner), key.0 == 0x04 { return key.1 }
        return data
    }
    static func validate(certificate: Data, key: Data) throws {
        guard let cert = SecCertificateCreateWithData(nil, der(certificate) as CFData),
              let publicKey = SecCertificateCopyKey(cert),
              let privateKey = SecKeyCreateWithData(rsaKeyDER(key) as CFData, [
                kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate
              ] as CFDictionary, nil),
              let derivedPublic = SecKeyCopyPublicKey(privateKey),
              let actual = SecKeyCopyExternalRepresentation(publicKey, nil),
              let expected = SecKeyCopyExternalRepresentation(derivedPublic, nil) else { throw Failure.invalidKey }
        guard actual as Data == expected as Data else { throw Failure.keyMismatch }
    }
    static func build(certificate: Data, key: Data, password: String, name: String) throws -> Data {
        guard !password.isEmpty, !password.contains("\0") else { throw Failure.invalidPassword }
        let certificate = der(certificate)
        let key = rsaKeyDER(key)
        try validate(certificate: certificate, key: key)
        let salt = try random(16), iv = try random(16), macSalt = try random(16)
        let rounds = 100_000
        var encryptionKey = Data(count: 32)
        let passwordBytes = Array(password.utf8)
        let status = encryptionKey.withUnsafeMutableBytes { output in
            salt.withUnsafeBytes { saltBytes in
                passwordBytes.withUnsafeBytes { input in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), input.baseAddress?.assumingMemoryBound(to: Int8.self), input.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(rounds), output.baseAddress?.assumingMemoryBound(to: UInt8.self), 32)
                }
            }
        }
        guard status == kCCSuccess else { throw Failure.crypto(status) }
        let pkcs8 = sequence(integer(0) + sequence(oid("1.2.840.113549.1.1.1") + tlv(0x05, Data())) + octet(key))
        let encryptedKey = try encrypt(pkcs8, key: encryptionKey, iv: iv)
        let pbkdf = sequence(oid("1.2.840.113549.1.5.12") + sequence(octet(salt) + integer(rounds) + integer(32) + sequence(oid("1.2.840.113549.2.9") + tlv(0x05, Data()))))
        let aes = sequence(oid("2.16.840.1.101.3.4.1.42") + octet(iv))
        let pbes2 = sequence(oid("1.2.840.113549.1.5.13") + sequence(pbkdf + aes))
        let localID = digest(certificate, sha1: true)
        let attrs = tlv(0x31, sequence(oid("1.2.840.113549.1.9.20") + tlv(0x31, tlv(0x1e, bmp(name)))) + sequence(oid("1.2.840.113549.1.9.21") + tlv(0x31, octet(localID))))
        let keyBag = sequence(oid("1.2.840.113549.1.12.10.1.2") + tlv(0xa0, sequence(pbes2 + octet(encryptedKey))) + attrs)
        let certBag = sequence(oid("1.2.840.113549.1.12.10.1.3") + tlv(0xa0, sequence(oid("1.2.840.113549.1.9.22.1") + tlv(0xa0, octet(certificate)))) + attrs)
        let safe = sequence(content(sequence(keyBag + certBag)))
        // PKCS#12 Appendix B key derivation, diversifier 3, SHA-256 (one block).
        let d = Data(repeating: 3, count: 64)
        func expand(_ bytes: Data) -> Data {
            guard !bytes.isEmpty else { return Data() }
            return Data((0..<(64 * ((bytes.count + 63) / 64))).map { bytes[$0 % bytes.count] })
        }
        var macKey = digest(d + expand(macSalt) + expand(bmp(password) + Data([0, 0])))
        for _ in 1..<rounds { macKey = digest(macKey) }
        var mac = Data(count: 32)
        mac.withUnsafeMutableBytes { output in
            macKey.withUnsafeBytes { keyBytes in
                safe.withUnsafeBytes { dataBytes in
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, macKey.count, dataBytes.baseAddress, safe.count, output.baseAddress)
                }
            }
        }
        let macData = sequence(sequence(sequence(oid("2.16.840.1.101.3.4.2.1") + tlv(0x05, Data())) + octet(mac)) + octet(macSalt) + integer(rounds))
        return sequence(integer(3) + content(safe) + macData)
    }
    struct Request: Sendable {
        let csr: Data
        let privateKey: Data
        let publicKey: Data
    }
    static func generateRequest(commonName: String, email: String, organization: String) throws -> Request {
        guard !commonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              email.unicodeScalars.allSatisfy({ $0.isASCII }) else { throw Failure.invalidKey }
        guard let key = SecKeyCreateRandomKey([
            kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048
        ] as CFDictionary, nil), let pub = SecKeyCopyPublicKey(key),
              let privateDER = SecKeyCopyExternalRepresentation(key, nil),
              let publicDER = SecKeyCopyExternalRepresentation(pub, nil) else { throw Failure.invalidKey }
        let algorithm = sequence(oid("1.2.840.113549.1.1.1") + tlv(0x05, Data()))
        let spki = sequence(algorithm + tlv(0x03, Data([0]) + (publicDER as Data)))
        var subject = tlv(0x31, sequence(oid("2.5.4.3") + tlv(0x0c, Data(commonName.utf8))))
        if !organization.isEmpty { subject += tlv(0x31, sequence(oid("2.5.4.10") + tlv(0x0c, Data(organization.utf8)))) }
        if !email.isEmpty { subject += tlv(0x31, sequence(oid("1.2.840.113549.1.9.1") + tlv(0x16, Data(email.utf8)))) }
        let info = sequence(integer(0) + sequence(subject) + spki + tlv(0xa0, Data()))
        guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, info as CFData, nil) else { throw Failure.invalidKey }
        let request = sequence(info + sequence(oid("1.2.840.113549.1.1.11") + tlv(0x05, Data())) + tlv(0x03, Data([0]) + (signature as Data)))
        return Request(csr: pem(request, label: "CERTIFICATE REQUEST"), privateKey: pem(privateDER as Data, label: "RSA PRIVATE KEY"), publicKey: pem(spki, label: "PUBLIC KEY"))
    }
    static func publicKey(forPrivateKey data: Data) throws -> Data {
        guard let key = SecKeyCreateWithData(rsaKeyDER(data) as CFData, [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate] as CFDictionary, nil),
              let pub = SecKeyCopyPublicKey(key), let bytes = SecKeyCopyExternalRepresentation(pub, nil) else { throw Failure.invalidKey }
        let algorithm = sequence(oid("1.2.840.113549.1.1.1") + tlv(0x05, Data()))
        return pem(sequence(algorithm + tlv(0x03, Data([0]) + (bytes as Data))), label: "PUBLIC KEY")
    }
    static func normalizedPublicKey(_ raw: Data) throws -> Data {
        let bytes = der(raw)
        var offset = 0
        var pkcs1 = bytes
        if let outer = read(bytes, offset: &offset), outer.0 == 0x30 {
            var inner = 0
            if let algorithm = read(outer.1, offset: &inner), algorithm.0 == 0x30,
               let bits = read(outer.1, offset: &inner), bits.0 == 0x03, bits.1.first == 0 {
                pkcs1 = Data(bits.1.dropFirst())
            }
        }
        guard SecKeyCreateWithData(pkcs1 as CFData, [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary, nil) != nil else { throw Failure.invalidKey }
        let algorithm = sequence(oid("1.2.840.113549.1.1.1") + tlv(0x05, Data()))
        return pem(sequence(algorithm + tlv(0x03, Data([0]) + pkcs1)), label: "PUBLIC KEY")
    }
    private static func random(_ count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw Failure.crypto(status) }
        return data
    }
    private static func encrypt(_ data: Data, key: Data, iv: Data) throws -> Data {
        var output = Data(count: data.count + kCCBlockSizeAES128)
        var length = 0
        let capacity = output.count
        let status = output.withUnsafeMutableBytes { out in key.withUnsafeBytes { keyBytes in iv.withUnsafeBytes { ivBytes in data.withUnsafeBytes { input in
            CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding), keyBytes.baseAddress, key.count, ivBytes.baseAddress, input.baseAddress, data.count, out.baseAddress, capacity, &length)
        } } } }
        guard status == kCCSuccess else { throw Failure.crypto(status) }
        output.count = length
        return output
    }
    private static func digest(_ data: Data, sha1: Bool = false) -> Data {
        var output = Data(count: sha1 ? 20 : 32)
        output.withUnsafeMutableBytes { out in data.withUnsafeBytes { input in
            if sha1 { _ = CC_SHA1(input.baseAddress, CC_LONG(data.count), out.baseAddress?.assumingMemoryBound(to: UInt8.self)) }
            else { _ = CC_SHA256(input.baseAddress, CC_LONG(data.count), out.baseAddress?.assumingMemoryBound(to: UInt8.self)) }
        } }
        return output
    }
    private static func bmp(_ string: String) -> Data { Data(string.utf16.flatMap { [UInt8($0 >> 8), UInt8($0 & 255)] }) }
    private static func content(_ bytes: Data) -> Data { sequence(oid("1.2.840.113549.1.7.1") + tlv(0xa0, octet(bytes))) }
    private static func sequence(_ bytes: Data) -> Data { tlv(0x30, bytes) }
    private static func octet(_ bytes: Data) -> Data { tlv(0x04, bytes) }
    private static func integer(_ number: Int) -> Data {
        var value = number, bytes: [UInt8] = []
        repeat { bytes.insert(UInt8(value & 255), at: 0); value >>= 8 } while value > 0
        if bytes[0] & 128 != 0 { bytes.insert(0, at: 0) }
        return tlv(0x02, Data(bytes))
    }
    private static func oid(_ string: String) -> Data {
        let values = string.split(separator: ".").map { Int($0)! }
        var bytes = [UInt8(values[0] * 40 + values[1])]
        for var value in values.dropFirst(2) {
            var group = [UInt8(value & 127)]; value >>= 7
            while value > 0 { group.insert(UInt8(value & 127) | 128, at: 0); value >>= 7 }
            bytes += group
        }
        return tlv(0x06, Data(bytes))
    }
    private static func tlv(_ tag: UInt8, _ bytes: Data) -> Data {
        var length = bytes.count, encoded: [UInt8] = []
        if length < 128 { encoded = [UInt8(length)] }
        else {
            while length > 0 { encoded.insert(UInt8(length & 255), at: 0); length >>= 8 }
            encoded.insert(0x80 | UInt8(encoded.count), at: 0)
        }
        return Data([tag] + encoded) + bytes
    }
    private static func read(_ data: Data, offset: inout Int) -> (UInt8, Data)? {
        let bytes = [UInt8](data)
        guard offset + 2 <= bytes.count else { return nil }
        let tag = bytes[offset]; offset += 1
        var length = Int(bytes[offset]); offset += 1
        if length & 128 != 0 {
            let count = length & 127; length = 0
            guard count > 0, count <= 4, offset + count <= bytes.count else { return nil }
            for _ in 0..<count { length = (length << 8) | Int(bytes[offset]); offset += 1 }
        }
        guard offset + length <= bytes.count else { return nil }
        defer { offset += length }
        return (tag, Data(bytes[offset..<(offset + length)]))
    }
}
