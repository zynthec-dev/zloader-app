//
//  CertificateProvisioningFlow.swift
//  ZLoader
//
//  Created by Magesh K on 13/09/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import Foundation
import SideSign

protocol CertificateProvisioningHandler: AnyObject, Sendable {
    func resolveRevocation(certificates: [ALTX509Certificate], teamType: ALTTeamType) async throws -> RevokeDecision
    func resolveProvisioningError(_ error: Error) async -> ProvisioningErrorDecision
}

final class CertificateProvisioningFlow: @unchecked Sendable {
    weak var handler: CertificateProvisioningHandler?
    let skipCertificateProvisioning: Bool
    private(set) var portalCertificates: [ALTX509Certificate]?
    
    init(handler: CertificateProvisioningHandler? = nil, skipCertificateProvisioning: Bool = false) {
        self.handler = handler
        self.skipCertificateProvisioning = skipCertificateProvisioning
    }
    
    func resolveCertificate(for team: ALTTeam) async throws -> ALTCertificate? {
        while true {
            do {
                return try await self.performCertificateResolution(for: team)
            } catch {
                if let handler = self.handler {
                    let decision = await handler.resolveProvisioningError(error)
                    switch decision {
                    case .retry:
                        continue
                    case .skip:
                        return nil
                    case .cancel:
                        throw OperationError.cancelled
                    }
                } else {
                    throw error
                }
            }
        }
    }
    
    private func performCertificateResolution(for team: ALTTeam) async throws -> ALTCertificate? {
        if skipCertificateProvisioning { return CertificateManager.shared.activeCertificate?.certificate }
        // Apple-account provisioning must resolve the selected team's identity,
        // even when the installer supplied an active certificate from another team.
        let certificate = try await fetchCertificate(for: team)
        try CertificateManager.shared.setActiveCertificate(certificate)
        return certificate
    }

    static func isUsable(_ certificate: ALTCertificate, portalCertificates: [ALTX509Certificate]) -> Bool {
        let matchingKey = certificate.data.map {
            (try? PortablePKCS12.validate(certificate: $0, key: certificate.privateKey)) != nil
        } ?? false
        return AccountCertificatePolicy.canReuse(certificate: certificate.data,
            expiresAt: certificate.certificate.notAfter, hasMatchingPrivateKey: matchingKey,
            portalCertificates: portalCertificates.map { $0.rawDER })
    }

    func fetchPortalCertificates(for team: ALTTeam) async throws -> [ALTX509Certificate] {
        if let cached = self.portalCertificates {
            return cached
        }
        let fetched = try await DeveloperPortalProxy.shared.fetchCertificates(team: team)
        self.portalCertificates = fetched
        return fetched
    }
    
    private func fetchCertificate(for team: ALTTeam) async throws -> ALTCertificate {
        let portalCertificates = try await DeveloperPortalProxy.shared.fetchCertificates(team: team)
        self.portalCertificates = portalCertificates
        
        let mainBundleCertSerial = CertificateManager.shared.getSigningCertificate(at: Bundle.Info.activeBundleURL)?.serialNumber
            ?? Bundle.main.object(forInfoDictionaryKey: Bundle.Info.certificateID) as? String
        
        var candidates = [CertificateManager.shared.activeCertificate?.certificate].compactMap { $0 }
        // Recover a matching embedded/local P12 before asking to replace any
        // certificate. This also supports a Side Installer identity with its key.
        if let mainBundleCertSerial,
           let remote = portalCertificates.first(where: { $0.serialNumber.caseInsensitiveCompare(mainBundleCertSerial) == .orderedSame }),
           let installed = CertificateManager.shared.getSignableCertificate(for: mainBundleCertSerial,
                                                                           fallbackPassword: remote.machineIdentifier) {
            candidates.append(installed)
        }
        candidates.append(contentsOf: CertificateManager.shared.getAllLocalCertificates())
        for candidate in candidates where Self.isUsable(candidate, portalCertificates: portalCertificates) {
            guard let remote = portalCertificates.first(where: { $0.rawDER == candidate.certificate.rawDER }) else { continue }
            var reused = candidate
            reused.machineIdentifier = remote.machineIdentifier
            return reused
        }
        if portalCertificates.isEmpty {
            return try await self.requestCertificate(for: team)
        } else {
            return try await self.replaceCertificate(portalCertificates: portalCertificates, for: team)
        }
    }
    
    private func requestCertificate(for team: ALTTeam) async throws -> ALTCertificate {
        let deviceName = await UIDevice.current.name
        let accountName = team.account?.firstName ?? team.name
        let machineName = "zLoader - \(accountName)'s \(deviceName)"
        debugLog("[CertificateProvisioningFlow] Requesting certificate for machineName '\(machineName)'...")

        do {
            let newPortalCertificate = try await DeveloperPortalProxy.shared.createCertificate(machineName: machineName, team: team)
            debugLog("[CertificateProvisioningFlow] Successfully requested new portal certificate (Serial: \(newPortalCertificate.serialNumber)).")
            
            let portalCertificates = try await DeveloperPortalProxy.shared.fetchCertificates(team: team)
            self.portalCertificates = portalCertificates

            let finalCert: ALTCertificate
            if let fullX509 = portalCertificates.first(where: { $0.serialNumber.lowercased() == newPortalCertificate.serialNumber.lowercased() }) {
                finalCert = ALTCertificate(x509: fullX509, privateKey: newPortalCertificate.privateKey)
            } else {
                finalCert = newPortalCertificate
            }

            return finalCert
        } catch {
            debugLog("[CertificateProvisioningFlow] requestCertificate: Failed with error: \(error)")
            throw error
        }
    }
    
    private func replaceCertificate(portalCertificates: [ALTX509Certificate], for team: ALTTeam) async throws -> ALTCertificate {
        let iosCertificates = portalCertificates.filter { cert in
            AccountCertificatePolicy.isIOSDevelopment(name: cert.name, portalType: cert.certificateType)
        }

        debugLog("[CertificateProvisioningFlow] replaceCertificate: Starting. Total certs on portal: \(portalCertificates.count), iOS Development certs: \(iosCertificates.count)")
        
        if iosCertificates.isEmpty {
            debugLog("[CertificateProvisioningFlow] replaceCertificate: No iOS Development certificates found on portal. Requesting new...")
            return try await self.requestCertificate(for: team)
        }
        
        if let handler = self.handler {
            debugLog("[CertificateProvisioningFlow] replaceCertificate: Presenting revoke alert for \(iosCertificates.count) iOS Development cert(s)...")
            let action = try await handler.resolveRevocation(certificates: iosCertificates, teamType: team.type)
            debugLog("[CertificateProvisioningFlow] replaceCertificate: User action was \(action)")
            switch action {
            case .keepExisting:
                debugLog("[CertificateProvisioningFlow] replaceCertificate: Keeping existing, calling requestCertificate...")
                return try await self.requestCertificate(for: team)
                
            case .revokeSelected(let certsToRevoke):
                debugLog("[CertificateProvisioningFlow] replaceCertificate: Revoking \(certsToRevoke.count) selected certificate(s)...")
                var firstError: Error? = nil

                for certificate in certsToRevoke {
                    do {
                        debugLog("[CertificateProvisioningFlow] replaceCertificate: Revoking certificate '\(certificate.machineName ?? certificate.name)' (Serial: \(certificate.serialNumber))...")
                        _ = try await DeveloperPortalProxy.shared.revokeCertificate(certificate, team: team)
                        debugLog("[CertificateProvisioningFlow] replaceCertificate: Revoke succeeded.")
                    } catch {
                        debugLog("[CertificateProvisioningFlow] replaceCertificate: Revoke failed with error: \(error)")
                        if firstError == nil {
                            firstError = error
                        }
                    }
                }

                if let error = firstError {
                    debugLog("[CertificateProvisioningFlow] replaceCertificate: Error occurred during revocation, throwing...")
                    throw error
                } else {
                    debugLog("[CertificateProvisioningFlow] replaceCertificate: Selected certificates successfully revoked. Requesting new certificate...")
                    return try await self.requestCertificate(for: team)
                }
            }
        } else {
            return try await self.requestCertificate(for: team)
        }
    }
}
