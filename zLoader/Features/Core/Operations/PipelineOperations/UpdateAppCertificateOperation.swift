//
//  UpdateAppCertificateOperation.swift
//  ZLoader
//
//  Created by Magesh K on 1/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import Foundation
import CoreData
import SideSign

final class UpdateAppCertificateOperation: BasePipelineOperation<InstallAppOperationContext, Void>, @unchecked Sendable {
    
    override func execute(parentProgress: Progress?) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[UpdateAppCertificateOperation] execute() started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[UpdateAppCertificateOperation] execute() took: \(String(format: "%.3fs", elapsed))")
        }
        try await super.executePreconditionCheck(parentProgress: parentProgress)
        
        // Explicit signing choices are validated by the next operation. An
        // installed/assigned historical identity must not overwrite that choice.
        guard context.overrideSigningCertificate == nil else {
            self.setProgress(100)
            return
        }
        let team = try await AuthManager.shared.getAuthenticatedTeam()
        let portal = try await DeveloperPortalProxy.shared.fetchCertificates(team: team)
        let targetBundleID = context.installedApp?.bundleIdentifier ?? context.targetBundleIdentifier
        let profileToUse = context.overrideProvisioningProfile ?? ProfileManager.shared.getAssignedProfile(for: targetBundleID)
        if let assignedProfile = profileToUse, assignedProfile.teamIdentifier == team.identifier {
            context.overrideProvisioningProfile = assignedProfile
            if let candidate = ProfileManager.shared.getMatchingCertificate(for: assignedProfile),
               CertificateProvisioningFlow.isUsable(candidate, portalCertificates: portal) {
                context.overrideSigningCertificate = candidate
            }
        }
        if context.overrideSigningCertificate == nil,
           let serial = context.installedApp?.certificateSerialNumber,
           let candidate = CertificateManager.shared.getSignableCertificate(for: serial),
           CertificateProvisioningFlow.isUsable(candidate, portalCertificates: portal) {
            context.overrideSigningCertificate = candidate
        }
        // If the old identity is unusable, retain the selected active account
        // identity. Fresh provisioning will replace its obsolete profile.

        self.setProgress(100)
    }
}
