//
//  CertificateStore.swift
//  ZLoader
//
//  Created by Magesh K on 3/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import SideSign

public enum CertificateStore {
    /// Loads an ALTCertificate from PKCS#12 data. If password is provided, decrypts with password; if nil, loads unencrypted PKCS#12.
    public static func load(_ data: Data, password: String?) throws -> ALTCertificate {
        if let password = password {
            return try ALTCertificate(p12Data: data, password: password)
        } else {
            return try ALTCertificate(p12Data: data)
        }
    }

    /// Exports an ALTCertificate to PKCS#12 data. If password is provided, encrypts PKCS#12 with password; if nil, exports unencrypted PKCS#12.
    public static func export(_ cert: ALTCertificate, password: String?) throws -> Data {
        if let password = password {
            guard let certificate = cert.data else { throw PortablePKCS12.Failure.invalidKey }
            return try PortablePKCS12.build(certificate: certificate, key: cert.privateKey, password: password, name: cert.machineName ?? cert.name)
        } else {
            return try cert.unencryptedP12Data()
        }
    }
}
