//
//  CertificateExporter.swift
//  ZLoader
//
//  Created by Magesh K on 2026-07-03.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import SideSign

enum CertificateExporter {
    
    static func sharePublicCertAsDER(_ cert: ALTX509Certificate, onShare: ((URL) -> Void)? = nil, onError: @escaping (String) -> Void) {
        guard let data = cert.data else { onError("Public certificate data is missing."); return }
        share(data: getDERData(from: data) ?? data, filename: (cert.machineName ?? cert.name) + ".der", onShare: onShare, onError: onError)
    }
    
    static func sharePublicCertAsPEM(_ cert: ALTX509Certificate, onShare: ((URL) -> Void)? = nil, onError: @escaping (String) -> Void) {
        guard let data = cert.data else { onError("Public certificate data is missing."); return }
        share(data: PortablePKCS12.pem(PortablePKCS12.der(data), label: "CERTIFICATE"), filename: (cert.machineName ?? cert.name) + ".pem", onShare: onShare, onError: onError)
    }
    
    static func copyPublicCertAsPEM(_ cert: ALTX509Certificate, onError: @escaping (String) -> Void) {
        #if !os(tvOS)
        guard let data = cert.data else { onError("Public certificate data is missing."); return }
        UIPasteboard.general.string = String(data: PortablePKCS12.pem(PortablePKCS12.der(data), label: "CERTIFICATE"), encoding: .utf8)
        #endif
    }
    
    static func shareP12(_ cert: ALTCertificate, password: String, onShare: ((URL) -> Void)? = nil, onError: @escaping (String) -> Void) {
        do {
            guard let certificate = cert.data else { throw PortablePKCS12.Failure.invalidKey }
            let p12Data = try PortablePKCS12.build(certificate: certificate, key: cert.privateKey, password: password, name: cert.machineName ?? cert.name)
            share(data: p12Data, filename: (cert.machineName ?? cert.name) + ".p12", onShare: onShare, onError: onError)
        } catch {
            debugLog("[CertificateExporter] Failed to build encrypted p12 data: \(error)")
            onError("Failed to build encrypted p12 data: \(error.localizedDescription)")
        }
    }
    
    static func sharePrivateKeyAsPEM(_ cert: ALTCertificate, onShare: ((URL) -> Void)? = nil, onError: @escaping (String) -> Void) {
        let keyData = cert.privateKey
        share(data: keyData, filename: (cert.machineName ?? cert.name) + "_key.pem", onShare: onShare, onError: onError)
    }
    
    static func sharePrivateKeyAsDER(_ cert: ALTCertificate, onShare: ((URL) -> Void)? = nil, onError: @escaping (String) -> Void) {
        let keyData = cert.privateKey
        share(data: getDERData(from: keyData) ?? keyData, filename: (cert.machineName ?? cert.name) + "_key.der", onShare: onShare, onError: onError)
    }
    
    static func copyPrivateKey(_ cert: ALTCertificate) {
        #if !os(tvOS)
        let keyData = cert.privateKey
        UIPasteboard.general.string = String(data: keyData, encoding: .utf8) ?? keyData.base64EncodedString()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    
    private static func share(data: Data, filename: String, onShare: ((URL) -> Void)? = nil, onError: @escaping (String) -> Void) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let tempURL = directory.appendingPathComponent(URL(fileURLWithPath: filename).lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: tempURL, options: [.atomic, .completeFileProtection])
        } catch {
            onError("Failed to write temp export file: " + error.localizedDescription)
            return
        }
        if let onShare = onShare {
            DispatchQueue.main.async {
                onShare(tempURL)
            }
            return
        }
        guard let rootVC = UIApplication.shared.topViewController() else { return }
        #if !os(tvOS)
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = rootVC.view.bounds
        }
        rootVC.present(activityVC, animated: true)
        #else
        TVWebFileTransferManager.shared.startExport(fileURL: tempURL, title: "Export Certificate / Key", presentingVC: rootVC)
        #endif
    }
}
