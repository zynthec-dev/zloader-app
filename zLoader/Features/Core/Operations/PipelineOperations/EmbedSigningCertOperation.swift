//
//  EmbedSigningCertOperation.swift
//  ZLoader
//
//  Created by Magesh K on 8/5/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import SideSign

final class EmbedSigningCertOperation: BasePipelineOperation<InstallAppOperationContext, Void>, @unchecked Sendable {
    override func execute(parentProgress: Progress?) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[EmbedSigningCertOperation] execute() started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[EmbedSigningCertOperation] execute() took: \(String(format: "%.3fs", elapsed))")
        }
        try await super.executePreconditionCheck(parentProgress: parentProgress)
        
        // 1. Resolve the certificate used for signing this app
        guard let cert = self.context.targetSigningCertificate else
        {
            throw OperationError.invalidParameters("EmbedSigningCertOperation: No signing certificate found in context.")
        }
        
        guard let appBundle = self.context.targetAppBundle else {
            throw OperationError.invalidParameters("EmbedSigningCertOperation: targetAppBundle is missing in context.")
        }
        // IPA distribution must never include an exportable signing private key.
        // Existing installations retain their active key in the local Keychain.
        for component in [appBundle] + appBundle.appExtensions {
            let keyArchive = component.fileURL.appendingPathComponent("ALTCertificate.p12")
            if FileManager.default.fileExists(atPath: keyArchive.path) {
                try FileManager.default.removeItem(at: keyArchive)
            }
        }
        let publicCertificate = appBundle.fileURL.appendingPathComponent("ALTCertificate.der")
        try cert.certificate.rawDER.write(to: publicCertificate, options: .atomic)
    }
}
