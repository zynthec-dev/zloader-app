//
//  FetchProvisioningProfilesOperation.swift
//  ZLoader
//
//  Created by Riley Testut on 2/27/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import SideSign
import CoreData

class FetchProvisioningProfilesOperation: BasePipelineOperation<InstallAppOperationContext, [String: ALTProvisioningProfile]>, @unchecked Sendable {
    
    override func execute(parentProgress: Progress?) async throws -> [String: ALTProvisioningProfile] {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[FetchProvisioningProfilesOperation] execute() started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[FetchProvisioningProfilesOperation] execute() took: \(String(format: "%.3fs", elapsed))")
        }
        try await super.executePreconditionCheck(parentProgress: parentProgress)
        if let error = self.context.error {
            self.debugLog("[FetchProvisioningProfiles] Context has pre-existing error: \(error.localizedDescription)")
            throw error
        }

        guard let targetAppBundle = self.context.targetAppBundle else {
            self.debugLog("[FetchProvisioningProfiles] Target app bundle missing in context.")
            throw OperationError.invalidParameters("FetchProvisioningProfilesOperation: context.targetAppBundle is nil")
        }

        let requiresTunnel = targetAppBundle.appExtensions.contains {
            ($0.infoPlist["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == "com.apple.networkextension.packet-tunnel"
        }
        if requiresTunnel {
            guard !self.context.useMainProfile else {
                throw OperationError.invalidParameters("zLoader's tunnel requires its own provisioning profile; using the main app profile for extensions is unsupported.")
            }
            if self.context.overrideProvisioningProfile == nil {
                let team = try await AuthManager.shared.getAuthenticatedTeam()
                guard team.type != .free else {
                    throw OperationError.invalidParameters("A free Apple account cannot provision the Network Extension required by this zLoader IPA. Use an eligible paid developer team and profiles authorizing packet-tunnel-provider. The entitlement will not be stripped or bypassed.")
                }
            }
        }

        let effectiveBundleId = self.context.targetBundleIdentifier

        let appExtensions = targetAppBundle.appExtensions
        guard !context.useMainProfile || appExtensions.isEmpty else {
            throw OperationError.invalidParameters("Each extension requires a separate app ID and provisioning profile.")
        }

        if let overrideProfile = self.context.overrideProvisioningProfile {
            self.debugLog("[FetchProvisioningProfiles] Using override provisioning profile '\(overrideProfile.name)' (\(overrideProfile.uuid)) for \(effectiveBundleId)")
            var profiles = [effectiveBundleId: overrideProfile]
            guard !context.useMainProfile || appExtensions.isEmpty else {
                throw OperationError.invalidParameters("Each extension requires its own profile and app ID. A host profile cannot authorize an extension.")
            }
            let team = try await AuthManager.shared.getAuthenticatedTeam()
            guard overrideProfile.bundleIdentifier == effectiveBundleId,
                  let validated = await reusableEmbeddedProfile(for: targetAppBundle, parentAppBundle: nil,
                                                               bundleID: effectiveBundleId, team: team), validated.uuid == overrideProfile.uuid else {
                throw OperationError.invalidParameters("The selected profile must authorize this app, certificate, team, device and every required entitlement.")
            }
            for appExtension in appExtensions {
                guard let identifier = PacketTunnelProvisioning.extensionBundleIdentifier(
                    appExtension.bundleIdentifier, parent: targetAppBundle.bundleIdentifier, resolvedParent: effectiveBundleId
                ), let profile = await reusableEmbeddedProfile(for: appExtension, parentAppBundle: targetAppBundle,
                                                              bundleID: identifier, team: team) else {
                    throw OperationError.invalidParameters("Import a compatible profile for extension " + appExtension.bundleIdentifier + ". The host profile cannot be reused for an extension.")
                }
                profiles[identifier] = profile
            }
            self.setProgress(100)
            return profiles
        }

        let team = try await AuthManager.shared.getAuthenticatedTeam()
        self.debugLog("[FetchProvisioningProfiles] Executing for app \(targetAppBundle.bundleIdentifier), targetBundleID: \(effectiveBundleId), team: \(team.identifier), useMainProfile: \(self.context.useMainProfile)")
        
        self.setProgress(10)

        self.debugLog("[FetchProvisioningProfiles] Preparing main provisioning profile for \(targetAppBundle.bundleIdentifier)...")
        let profile = try await self.provisionAndFetchProfile(for: targetAppBundle, parentAppBundle: nil, team: team)
        self.debugLog("[FetchProvisioningProfiles] Main profile prepared successfully for \(effectiveBundleId), expiration: \(String(describing: profile.expirationDate))")
        
        var profiles = [effectiveBundleId: profile]
        
        guard !self.context.useMainProfile, !appExtensions.isEmpty else {
            self.setProgress(100)
            self.debugLog("[FetchProvisioningProfiles] Total profiles prepared: \(profiles.count) -> keys: \(Array(profiles.keys))")
            return profiles
        }
        
        self.setProgress(50)
        self.debugLog("[FetchProvisioningProfiles] Preparing profiles for \(appExtensions.count) app extensions...")
        try await withThrowingTaskGroup(of: (String, ALTProvisioningProfile).self) { group in
            for appExtension in appExtensions {
                group.addTask {
                    self.verboseLog("[FetchProvisioningProfiles] Preparing extension profile for \(appExtension.bundleIdentifier)...")
                    let extProfile = try await self.provisionAndFetchProfile(for: appExtension, parentAppBundle: targetAppBundle, team: team, resolvedParentID: profile.bundleIdentifier)
                    // Use customized bundle ID if applicable
                    let updatedExtensionBundleId = appExtension.bundleIdentifier.replacingOccurrences(of: targetAppBundle.bundleIdentifier, with: effectiveBundleId)
                    self.verboseLog("[FetchProvisioningProfiles] Extension profile prepared for \(updatedExtensionBundleId)")
                    return (updatedExtensionBundleId, extProfile)
                }
            }
            
            var completedCount = 0
            let totalExtensions = appExtensions.count
            let startProgress = self.progress.completedUnitCount
            let endProgress: Int64 = 100
            let range = endProgress - startProgress
            
            for try await (bundleId, extProfile) in group {
                profiles[bundleId] = extProfile
                self.debugLog("[FetchProvisioningProfiles] Added profile for extension bundle ID: \(bundleId)")
                completedCount += 1
                if range > 0 {
                    let percent = startProgress + Int64(Double(completedCount) / Double(totalExtensions) * Double(range))
                    self.setProgress(percent)
                }
            }
        }
        
        self.debugLog("[FetchProvisioningProfiles] Total profiles prepared: \(profiles.count) -> keys: \(Array(profiles.keys))")
        return profiles
    }


    private func getPreferredBundleID(for targetAppBundle: ALTApplication, team: ALTTeam) async -> String? {
        await DatabaseManager.shared.persistentContainer.performBackgroundTask { [weak self] (context) -> String? in
            guard let self else { return nil }
            let target = self.context.targetBundleIdentifier
            let predicate = NSPredicate(
                format: "(%K == %@) OR (%K == %@)",
                #keyPath(InstalledApp.customBundleIdentifier), target,
                #keyPath(InstalledApp.resignedBundleIdentifier), target
            )
            guard let installedApp = InstalledApp.first(satisfying: predicate, in: context) else {
                self.verboseLog("[FetchProvisioningProfiles] No existing InstalledApp found for target: \(target)")
                return nil
            }
            
            // Teams match if installedApp.team has same identifier as team (or team is nil)
            // AND installedApp.resignedBundleIdentifier actually contains the team's identifier.
            let teamsMatch = (installedApp.team?.identifier == team.identifier || installedApp.team == nil)
                             && installedApp.resignedBundleIdentifier.contains(team.identifier)
            
            self.verboseLog("[FetchProvisioningProfiles] preferredBundleID check: app=\(targetAppBundle.bundleIdentifier), installedResignedID=\(installedApp.resignedBundleIdentifier), installedTeam=\(installedApp.team?.identifier ?? "nil"), targetTeam=\(team.identifier), teamsMatch=\(teamsMatch)")

            // TODO: @mahee96: Try to keep the debug build and release build operations similar, refactor later with proper reasoning
            //                 for now, restricted it to debug on simulator only
            #if DEBUG && targetEnvironment(simulator)

            let result = teamsMatch ? installedApp.resignedBundleIdentifier : nil
            self.debugLog("[FetchProvisioningProfiles] preferredBundleID result (DEBUG simulator): \(result ?? "nil")")
            return result

            #else
            
            let result = teamsMatch ? installedApp.resignedBundleIdentifier : nil
            self.debugLog("[FetchProvisioningProfiles] preferredBundleID result: \(result ?? "nil")")
            return result
            
            #endif
        }
    }
    
    private func provisionAndFetchProfile(for targetAppBundle: ALTApplication,
                                          parentAppBundle: ALTApplication?,
                                          team: ALTTeam, resolvedParentID: String? = nil) async throws -> ALTProvisioningProfile {
        let parentID: String
        if let resolvedParentID {
            parentID = resolvedParentID
        } else if parentAppBundle == nil, targetAppBundle.isZLoaderApp,
                  let running = ALTApplication(fileURL: Bundle.Info.activeBundleURL),
                  let identity = PacketTunnelProvisioning.preservedHostIdentity(
                    bundleID: running.bundleIdentifier, profileTeam: running.provisioningProfile?.teamIdentifier,
                    selectedTeam: team.identifier
                  ) {
            // The Release update's ID must not replace the running Debug/custom ID.
            parentID = identity
        } else if let preferredBundleID = await self.getPreferredBundleID(for: targetAppBundle, team: team) {
            parentID = preferredBundleID
        } else if parentAppBundle == nil, targetAppBundle.isZLoaderApp,
                  let profile = targetAppBundle.provisioningProfile,
                  profile.bundleIdentifier == context.targetBundleIdentifier,
                  profile.teamIdentifier == team.identifier {
            // A certificate change within the same team does not require a new app identity.
            parentID = context.targetBundleIdentifier
        } else if self.context.appendTeamID {
            parentID = PacketTunnelProvisioning.appendingTeamOnce(to: context.targetBundleIdentifier, teamID: team.identifier)
        } else {
            parentID = self.context.targetBundleIdentifier
        }

        let bundleID: String
        if let parentAppBundle = parentAppBundle {
            guard let resolvedExtensionID = PacketTunnelProvisioning.extensionBundleIdentifier(
                targetAppBundle.bundleIdentifier, parent: parentAppBundle.bundleIdentifier, resolvedParent: parentID
            ) else {
                throw OperationError.invalidApp(reason: "Extension bundle ID '\(targetAppBundle.bundleIdentifier)' does not start with parent bundle ID '\(parentAppBundle.bundleIdentifier)'.")
            }
            bundleID = resolvedExtensionID
            self.debugLog("[FetchProvisioningProfiles] Extension bundleID with suffix: \(bundleID)")
        } else {
            bundleID = parentID
            self.debugLog("[FetchProvisioningProfiles] App bundleID: \(bundleID)")
        }
        
        let preferredName: String
        
        if let parentAppBundle = parentAppBundle {
            preferredName = parentAppBundle.name + " " + targetAppBundle.name
        } else {
            preferredName = targetAppBundle.name
        }
        
        // Apple-account signing always synchronizes capabilities and associations first.
        // An embedded profile may predate portal or entitlement edits; imported-identity
        // signing is validated separately above and never mutates the developer account.
        self.debugLog("[FetchProvisioningProfiles] Registering App ID with name '\(preferredName)' and bundleID '\(bundleID)'...")
        let appID = try await self.registerAppID(for: targetAppBundle, name: preferredName, bundleIdentifier: bundleID, team: team)
        self.debugLog("[FetchProvisioningProfiles] App ID registered successfully: \(appID.bundleIdentifier) (\(appID.identifier))")
        
        self.debugLog("[FetchProvisioningProfiles] Updating features for App ID \(appID.bundleIdentifier)...")
        let updatedAppID = try await self.updateFeatures(for: appID, targetAppBundle: targetAppBundle, team: team)
        
        self.debugLog("[FetchProvisioningProfiles] Updating app groups for App ID \(updatedAppID.bundleIdentifier)...")
        let (groupAppID, requiredGroups) = try await self.updateAppGroups(for: updatedAppID, targetAppBundle: targetAppBundle, team: team)
        
        verboseLog(targetAppBundle.dumpMachOInfo())
        self.debugLog("[FetchProvisioningProfiles] Fetching provisioning profile from Apple for App ID \(groupAppID.bundleIdentifier)...")
        let profile: ALTProvisioningProfile
        if team.type.isPaid {
            profile = try await createCertificateBoundProfile(for: groupAppID, app: targetAppBundle, requiredGroups: requiredGroups, team: team)
        } else {
            profile = try await DeveloperPortalProxy.shared.downloadProvisioningProfile(for: groupAppID, deviceType: DeveloperPortalProxy.currentDeviceType, team: team)
        }
        if !team.type.isPaid, let certificate = context.targetSigningCertificate {
            let udid = try await safeFetchUDID()
            let snapshot = EmbeddedProfileSnapshot(bundleID: profile.bundleIdentifier, teamID: profile.teamIdentifier,
                expiresAt: profile.expirationDate, certificates: profile.certificates.map { $0.rawDER },
                devices: profile.deviceIDs, entitlements: profile.entitlements)
            let target = ProfileReuseRequirements(bundleID: groupAppID.bundleIdentifier, teamID: team.identifier,
                certificate: certificate.certificate.rawDER, deviceID: udid,
                entitlements: requestedEntitlements(for: targetAppBundle, team: team))
            let omitted = EmbeddedProfileReuse.optionalCapabilityOmissions(snapshot, for: target)
            if !omitted.isEmpty { context.recordOptionalEntitlementOmissions(omitted, for: targetAppBundle.bundleIdentifier) }
        }
        self.debugLog("[FetchProvisioningProfiles] Provisioning profile fetched for \(groupAppID.bundleIdentifier) (Name: \(profile.name), Expiration: \(String(describing: profile.expirationDate)))")
        if requiresPacketTunnelCapability(for: targetAppBundle),
           !PacketTunnelProvisioning.isAuthorized(by: profile.entitlements) {
            throw OperationError.invalidParameters(PacketTunnelProvisioning.failureMessage(for: groupAppID.bundleIdentifier))
        }
        return profile
    }
}


private extension FetchProvisioningProfilesOperation{
        
    func registerAppID(for targetAppBundle: ALTApplication,
                               name: String,
                               bundleIdentifier: String,
                               team: ALTTeam) async throws -> ALTAppID {
        let appIDs = try await TaskChainCoalescer.shared.coalesce(key: "fetch_app_ids_\(team.identifier)") {
            if let cachedAppIDs = self.context.sharedContext.appIDs {
                self.debugLog("[FetchProvisioningProfiles] Using cached App IDs from shared context.")
                return cachedAppIDs
            }
            self.debugLog("[FetchProvisioningProfiles] Fetching existing App IDs from Apple for team \(team.identifier)...")
            let fetchedAppIDs = try await DeveloperPortalProxy.shared.fetchAppIDs(for: team)
            self.context.sharedContext.appIDs = fetchedAppIDs
            self.verboseLog("[FetchProvisioningProfiles] Found \(fetchedAppIDs.count) existing App IDs on portal for team \(team.identifier): \(fetchedAppIDs.map { $0.bundleIdentifier })")
            return fetchedAppIDs
        }
        
        if let appID = appIDs.first(where: { $0.bundleIdentifier.lowercased() == bundleIdentifier.lowercased() }) {
            self.debugLog("[FetchProvisioningProfiles] Found existing App ID on portal: \(appID.bundleIdentifier)")
            return appID
        } else {
            let requiredAppIDs = 1 + targetAppBundle.appExtensions.count
            let availableAppIDs = max(0, Team.maximumFreeAppIDs - appIDs.count)
            self.verboseLog("[FetchProvisioningProfiles] App ID not found on portal for '\(bundleIdentifier)'. Required: \(requiredAppIDs), Available: \(availableAppIDs) (teamType: \(team.type))")
            
            
            let appIDName = self.sanitizeAppIDName(name: name, bundleIdentifier: bundleIdentifier)
            
            self.debugLog("[FetchProvisioningProfiles] Calling DeveloperPortalProxy.shared.addAppID with name '\(appIDName)' and identifier '\(bundleIdentifier)'...")
            let appID = try await DeveloperPortalProxy.shared.addAppID(name: appIDName, bundleIdentifier: bundleIdentifier, team: team)
            self.context.sharedContext.appendAppID(appID)
            self.debugLog("[FetchProvisioningProfiles] Successfully registered new App ID '\(appID.bundleIdentifier)' on Apple portal.")
            return appID
        }
    }
    
    /// Ask Apple to issue a separate profile for the actual active key, rather
    /// than downloading an automatically managed Xcode profile for another key.
    func createCertificateBoundProfile(for appID: ALTAppID, app: ALTApplication, requiredGroups: [String],
                                       team: ALTTeam) async throws -> ALTProvisioningProfile {
        guard team.type != .free, let signing = context.targetSigningCertificate else {
            throw OperationError.invalidParameters("Managed provisioning requires a paid team and an active signing certificate with its private key.")
        }
        let certificates = try await DeveloperPortalProxy.shared.fetchCertificates(team: team)
        guard let certificate = certificates.first(where: { $0.rawDER == signing.certificate.rawDER }),
              let certificateID = certificate.identifier, !certificateID.isEmpty else {
            throw OperationError.invalidParameters("The active signing certificate is not registered in the selected Apple team. Select its team or an eligible certificate from that team.")
        }
        let device = try await TaskChainCoalescer.shared.coalesce(key: "zloader_profile_device_" + team.identifier) {
            let udid: String
            do {
                udid = try await safeFetchUDID()
            } catch {
                throw OperationError.invalidParameters("Cannot authorize this device because its UDID could not be read through the active pairing transport. A valid Remote Pairing file is sufficient for Remote Pairing mode; a separate Lockdown file is not required. Underlying device-service error: " + error.localizedDescription)
            }
            let devices = try await DeveloperPortalProxy.shared.fetchDevices(for: team)
            if let existing = devices.first(where: { $0.identifier.caseInsensitiveCompare(udid) == .orderedSame }) {
                return existing
            }
            return try await DeveloperPortalProxy.shared.registerDevice(name: "zLoader device", identifier: udid, team: team)
        }
        guard device.deviceID?.isEmpty == false else {
            throw OperationError.invalidParameters("Apple did not return a registered device ID for this iPhone. Device registration must complete before provisioning.")
        }
        if let status = device.status, status.lowercased().contains("disabled") || status.lowercased().contains("ineligible") {
            throw OperationError.invalidParameters("This device is not eligible for provisioning in the selected Apple team (\(status)). Check its registration in Certificates, Identifiers & Profiles.")
        }
        var authorizedDevices = [device]
        let includesSharingDevices = context.includeAllRegisteredDevices ||
            (context.targetAppBundle?.isZLoaderApp == true && UserDefaults.standard.isExportResignedAppEnabled)
        if includesSharingDevices {
            let registered = try await DeveloperPortalProxy.shared.fetchDevices(for: team)
            authorizedDevices += registered.filter { other in
                let status = other.status?.lowercased() ?? "enabled"
                #if os(tvOS)
                let matchesPlatform = other.type.contains(.appleTV)
                #else
                let matchesPlatform = other.type.contains(.iPhone) || other.type.contains(.iPad)
                #endif
                return matchesPlatform && !status.contains("disabled") && !status.contains("ineligible") &&
                    other.deviceID != nil && other.identifier != device.identifier
            }
        }
        let registeredIDs = Array(Set(authorizedDevices.compactMap(\.deviceID))).sorted()
        let registeredUDIDs = Set(authorizedDevices.map { $0.identifier.lowercased() })
        let isDistribution = certificate.name.lowercased().contains("distribution") ||
            certificate.certificateType?.lowercased().contains("distribution") == true
        #if os(tvOS)
        let profileType: ALTProfileType = isDistribution ? .tvOSAdHoc : .tvOS
        #else
        let profileType: ALTProfileType = isDistribution ? .adHoc : .iOS
        #endif
        var required = requestedEntitlements(for: app, team: team)
        if !requiredGroups.isEmpty { required["com.apple.security.application-groups"] = requiredGroups }
        var target = ProfileReuseRequirements(bundleID: appID.bundleIdentifier, teamID: team.identifier,
                                              certificate: signing.certificate.rawDER, deviceID: device.identifier, entitlements: required)
        let managedName = "zLoader " + appID.bundleIdentifier + " " + String(certificate.serialNumber.suffix(8))
        func compatible(_ profile: ALTProvisioningProfile) -> Bool {
            let snapshot = EmbeddedProfileSnapshot(
                bundleID: profile.bundleIdentifier, teamID: profile.teamIdentifier, expiresAt: profile.expirationDate,
                certificates: profile.certificates.map { $0.rawDER }, devices: profile.deviceIDs, entitlements: profile.entitlements
            )
            let omitted = EmbeddedProfileReuse.optionalCapabilityOmissions(snapshot, for: target)
            let reduced = ProfileReuseRequirements(bundleID: target.bundleID, teamID: target.teamID,
                certificate: target.certificate, deviceID: target.deviceID,
                entitlements: target.entitlements.filter { !omitted.contains($0.key) })
            guard EmbeddedProfileReuse.accepts(snapshot, for: reduced, requiredDevices: registeredUDIDs) else { return false }
            if !omitted.isEmpty {
                context.recordOptionalEntitlementOmissions(omitted, for: app.bundleIdentifier)
            }
            return true
        }
        // Check actual authorization, not profile names. An update can reuse the
        // installed profile even when the downloaded IPA contains no profile.
        var localCandidates = [app.provisioningProfile, context.overrideProvisioningProfile].compactMap { $0 }
        localCandidates.append(contentsOf: ProfileManager.shared.getAllLocalProfiles())
        if context.targetAppBundle?.isZLoaderApp == true,
           let running = ALTApplication(fileURL: Bundle.Info.activeBundleURL),
           let installed = ([running] + running.appExtensions).first(where: { $0.bundleIdentifier == appID.bundleIdentifier }),
           let profile = installed.provisioningProfile {
            localCandidates.insert(profile, at: 0)
        }
        if let profile = localCandidates.first(where: compatible) {
            self.debugLog("[FetchProvisioningProfiles] Reusing compatible installed/local profile without issuing a profile.")
            return profile
        }
        let existing = try await DeveloperPortalProxy.shared.listProvisioningProfiles(team: team)
        let candidates = existing.filter {
            $0.identifier != nil && ($0.bundleIdentifier.map { EmbeddedProfileReuse.matchesBundleID($0, target: appID.bundleIdentifier) } == true ||
                $0.bundleIdentifier == nil || ManagedProfileNaming.isOwned($0.name, base: managedName))
        }.sorted { ($0.identifier ?? "") < ($1.identifier ?? "") }
        var selectedID: String?
        var downloadError: Error?
        for item in candidates {
            guard let identifier = item.identifier else { continue }
            let candidate: ALTProvisioningProfile
            do {
                candidate = try await DeveloperPortalProxy.shared.downloadProvisioningProfile(profileID: identifier, team: team)
            } catch {
                downloadError = error
                continue
            }
            if compatible(candidate) {
                _ = try ProfileManager.shared.importProfile(data: candidate.data)
                self.debugLog("[FetchProvisioningProfiles] Reusing compatible portal profile without regenerating it.")
                return candidate
            }
            // Only an incompatible profile owned by this flow may be regenerated.
            // Continue searching: another duplicate or Xcode profile may already fit.
            if selectedID == nil, ManagedProfileNaming.isOwned(item.name, base: managedName),
               candidate.bundleIdentifier == appID.bundleIdentifier, candidate.teamIdentifier == team.identifier {
                selectedID = identifier
            }
        }
        if let downloadError { throw downloadError }
        let profile: ALTProvisioningProfile
        if let identifier = selectedID {
            profile = try await DeveloperPortalProxy.shared.updateProvisioningProfile(
                profileID: identifier, name: ManagedProfileNaming.uniqueName(base: managedName, identity: identifier),
                appIDId: appID.identifier, certificateIDs: [certificateID], deviceIDs: registeredIDs, type: profileType, team: team
            )
        } else {
            // A unique first name also prevents collisions between concurrent first
            // requests. Subsequent refreshes find this owned profile and renew its ID.
            profile = try await DeveloperPortalProxy.shared.createProvisioningProfile(
                name: ManagedProfileNaming.uniqueName(base: managedName, identity: UUID().uuidString),
                appID: appID, certificateIDs: [certificateID], deviceIDs: registeredIDs, type: profileType, team: team
            )
        }
        let snapshot = EmbeddedProfileSnapshot(
            bundleID: profile.bundleIdentifier, teamID: profile.teamIdentifier, expiresAt: profile.expirationDate,
            certificates: profile.certificates.map { $0.rawDER }, devices: profile.deviceIDs, entitlements: profile.entitlements
        )
        let omitted = EmbeddedProfileReuse.optionalCapabilityOmissions(snapshot, for: target)
        if !omitted.isEmpty {
            context.recordOptionalEntitlementOmissions(omitted, for: app.bundleIdentifier)
            target = ProfileReuseRequirements(bundleID: target.bundleID, teamID: target.teamID,
                certificate: target.certificate, deviceID: target.deviceID,
                entitlements: target.entitlements.filter { !omitted.contains($0.key) })
            self.debugLog("[FetchProvisioningProfiles] Apple did not grant optional capabilities; signing without: " + omitted.sorted().joined(separator: ", "))
        }
        var failures = EmbeddedProfileReuse.incompatibilities(snapshot, for: target)
        if !registeredUDIDs.isSubset(of: Set(profile.deviceIDs.map { $0.lowercased() })) {
            failures.append(NSLocalizedString("The profile does not authorize all selected registered devices.", comment: ""))
        }
        guard failures.isEmpty else {
            throw OperationError.invalidParameters("Apple's newly issued profile for " + appID.bundleIdentifier +
                " was rejected: " + failures.joined(separator: "; ") + ". No signing permissions were bypassed.")
        }
        if context.targetAppBundle?.isZLoaderApp == true,
           let groups = app.entitlements["com.apple.security.application-groups"] as? [String], !groups.isEmpty,
           (profile.entitlements["com.apple.security.application-groups"] as? [String] ?? []).isEmpty {
            throw OperationError.invalidParameters("Apple's newly issued profile omits the App Groups required by " + appID.bundleIdentifier)
        }
        // Retain the issued profile for subsequent refreshes with this key.
        _ = try ProfileManager.shared.importProfile(data: profile.data)
        return profile
    }

    func reusableEmbeddedProfile(for app: ALTApplication, parentAppBundle: ALTApplication?,
                                 bundleID: String, team: ALTTeam) async -> ALTProvisioningProfile? {
        if context.includeAllRegisteredDevices ||
            (context.targetAppBundle?.isZLoaderApp == true && UserDefaults.standard.isExportResignedAppEnabled) { return nil }
        guard let certificate = context.targetSigningCertificate,
              let validUntil = certificate.certificate.notAfter, validUntil > Date() else { return nil }

        var candidates = [app.provisioningProfile].compactMap { $0 }
        if parentAppBundle == nil, let overrideProfile = context.overrideProvisioningProfile {
            candidates = [overrideProfile]
        }
        // Each extension needs its own profile. Imported profiles are candidates,
        // never blanket overrides; the same strict authorization checks apply.
        if parentAppBundle != nil || context.overrideProvisioningProfile == nil {
            candidates.append(contentsOf: ProfileManager.shared.getAllLocalProfiles())
        }
        // An unsigned update may omit profiles; the running installation can supply its own.
        if context.targetAppBundle?.isZLoaderApp == true,
           let running = ALTApplication(fileURL: Bundle.Info.activeBundleURL) {
            let current = ([running] + running.appExtensions).first { $0.bundleIdentifier == bundleID }
            if let profile = current?.provisioningProfile { candidates.append(profile) }
        }
        let matching = candidates.filter {
            $0.bundleIdentifier == bundleID && $0.teamIdentifier == team.identifier &&
            $0.expirationDate > Date() &&
            $0.certificates.contains { $0.rawDER == certificate.certificate.rawDER }
        }
        guard !matching.isEmpty, let deviceID = try? await safeFetchUDID() else { return nil }
        let required = requestedEntitlements(for: app, team: team)
        return matching.first { profile in
            var candidateRequirements = required
            if let groups = required["com.apple.security.application-groups"] as? [String],
               let granted = profile.entitlements["com.apple.security.application-groups"] as? [String] {
                candidateRequirements["com.apple.security.application-groups"] = groups.map {
                    granted.contains($0) ? $0 : $0 + "." + team.identifier
                }
            }
            let target = ProfileReuseRequirements(bundleID: bundleID, teamID: team.identifier,
                                                  certificate: certificate.certificate.rawDER,
                                                  deviceID: deviceID, entitlements: candidateRequirements)
            return EmbeddedProfileReuse.accepts(EmbeddedProfileSnapshot(
                bundleID: profile.bundleIdentifier, teamID: profile.teamIdentifier,
                expiresAt: profile.expirationDate, certificates: profile.certificates.map { $0.rawDER },
                devices: profile.deviceIDs, entitlements: profile.entitlements
            ), for: target)
        }
    }

    func requiresPacketTunnelCapability(for app: ALTApplication) -> Bool {
        PacketTunnelProvisioning.requiresCapability(
            infoPlist: app.infoPlist, extensions: app.appExtensions.map { $0.infoPlist }
        )
    }

    func requestedEntitlements(for app: ALTApplication, team: ALTTeam) -> [String: Any] {
        let editedHost = app.bundleIdentifier == context.targetAppBundle?.bundleIdentifier ? context.customEntitlementsByBundleID[context.targetBundleIdentifier] : nil
        var entitlements = editedHost ?? context.customEntitlementsByBundleID[app.bundleIdentifier] ?? app.entitlements
        // Host customization must not add host-only capabilities to extensions.
        if app.bundleIdentifier == context.targetAppBundle?.bundleIdentifier {
            for (key, value) in context.additionalEntitlements { entitlements[key] = value }
        }
        let groups = runningOwnAppGroups(for: app, team: team)
        if !groups.isEmpty { entitlements[ALTEntitlement.appGroups.rawValue] = groups }
        return PacketTunnelProvisioning.requestedEntitlements(entitlements, required: requiresPacketTunnelCapability(for: app))
    }

    /// Unsigned self-update IPAs cannot declare their installed shared container.
    /// Restore it only for our host/widget within the same authorized team.
    func runningOwnAppGroups(for app: ALTApplication, team: ALTTeam) -> [String] {
        let point = (app.infoPlist["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String
        guard context.targetAppBundle?.isZLoaderApp == true,
              app.isZLoaderApp && point == nil || point == "com.apple.widgetkit-extension",
              let running = ALTApplication(fileURL: Bundle.Info.activeBundleURL),
              running.provisioningProfile?.teamIdentifier == team.identifier else { return [] }
        return running.provisioningProfile?.entitlements[ALTEntitlement.appGroups.rawValue] as? [String] ?? []
    }

    func updateFeatures(for appID: ALTAppID, targetAppBundle: ALTApplication, team: ALTTeam) async throws -> ALTAppID {
        let entitlements = requestedEntitlements(for: targetAppBundle, team: team)

        guard let allowedFeatures = team.type.allowedFeatures else {
            throw OperationError.invalidParameters("Cannot update features for unknown team type.")
        }
        
        var targetFeatures: [ALTFeature: String] = [:]
        var droppedFeatures: Set<ALTFeature> = []
        
        // Filter applicable features
        for (key, value) in entitlements {
            guard let feature = ALTFeature(entitlement: ALTEntitlement(rawValue: key)) else { 
                continue 
            }
            let isEnabled = (value as? [Any]).map { !$0.isEmpty } ?? (value as? Bool) ?? true
            guard isEnabled else { continue }
            
            if allowedFeatures.contains(feature) {
                targetFeatures[feature] = isEnabled ? "true" : "false"
            } else {
                droppedFeatures.insert(feature)
            }
        }
        
        // Force apply mandatory features
        for feature in AppConstants.mandatoryFeatures {
            if allowedFeatures.contains(feature) {
                targetFeatures[feature] = "true"
            } else {
                droppedFeatures.insert(feature)
            }
        }
        
        if !droppedFeatures.isEmpty {
            let bulleted = droppedFeatures.map { "  • \($0.rawValue)" }.joined(separator: "\n")
            self.debugLog("[FetchProvisioningProfiles] Team cannot request these capabilities; profile-authorized signing will omit unavailable rights:\n" + bulleted)
        }
        
        // check if we really need to make a update on portal
        let currentFeatures = appID.features
        let needsUpdate = targetFeatures.contains { feature, targetValue in
            // if not available yet assume feature = off
            let currentValue = currentFeatures[feature] ?? "false"
            return currentValue != targetValue
        }
        guard needsUpdate else { 
            self.debugLog("[FetchProvisioningProfiles] Features for App ID \(appID.bundleIdentifier) are already satisfied. Skipping portal update.")
            return appID 
        }
        
        // set for requesting and send request
        var appID = appID
        appID.features.merge(targetFeatures) { _, requested in requested }
        
        do {
            let updated = try await DeveloperPortalProxy.shared.updateAppID(appID, team: team, requireFeatureReadback: false)
            self.verboseLog("[FetchProvisioningProfiles] Updated features for App ID \(updated.bundleIdentifier).")
            return updated
        } catch {
            self.debugLog("[FetchProvisioningProfiles] Failed to update features for App ID \(appID.bundleIdentifier). \(error.localizedDescription)")
            throw error
        }
    }
    
    func updateAppGroups(for appID: ALTAppID, targetAppBundle: ALTApplication, team: ALTTeam) async throws -> (ALTAppID, [String]) {
        var entitlements = requestedEntitlements(for: targetAppBundle, team: team)
                
        let installedGroups = runningOwnAppGroups(for: targetAppBundle, team: team)
        let preservesRunningGroups = !installedGroups.isEmpty
        if preservesRunningGroups { entitlements[ALTEntitlement.appGroups.rawValue] = installedGroups }
        guard var applicationGroups = entitlements[ALTEntitlement.appGroups.rawValue] as? [String], !applicationGroups.isEmpty else {
            verboseLog("[FetchProvisioningProfiles] App ID \(appID.bundleIdentifier) has no app groups, skipping assignment.")
            // Assigning an App ID to an empty app group array fails,
            // so just do nothing if there are no app groups.
            return (appID, [])
        }
        
        for group in applicationGroups {
            if group.contains("$(APP_GROUP_IDENTIFIER)") {
                self.debugLog("[FetchProvisioningProfiles] Error: Application group contains raw placeholder '$(APP_GROUP_IDENTIFIER)': \(group)")
                throw OperationError.invalidParameters("Application group '\(group)' contains raw placeholder '$(APP_GROUP_IDENTIFIER)'.")
            }
        }
        
        if !preservesRunningGroups, targetAppBundle.isZLoaderApp, targetAppBundle.provisioningProfile?.teamIdentifier != team.identifier {
            verboseLog("[FetchProvisioningProfiles] Application groups before modifying for zLoader: \(applicationGroups)")
            
            // Remove app groups that contain ZLoader since they can be problematic (cause ZLoader to expire early)
            for (index, group) in applicationGroups.enumerated() {
                if group.contains("AltStore") {
                    verboseLog("[FetchProvisioningProfiles] Removing application group: \(group)")
                    applicationGroups.remove(at: index)
                }
            }
            
            // Make sure we add .AltWidget for the widget
            var zLoaderAppGroupID = Bundle.baseZLoaderAppGroupID
            for (_, group) in applicationGroups.enumerated() {
                if group.contains("AltWidget") {
                    zLoaderAppGroupID += ".AltWidget"
                    break
                }
            }
            
            // Potentially updating app groups for this specific ZLoader.
            // Find the (unique) ZLoader app group, then replace it
            // with the correct "base" app group ID.
            // Otherwise, we may append a duplicate team identifier to the end.
            if let index = applicationGroups.firstIndex(where: { $0.contains(Bundle.baseZLoaderAppGroupID) }) {
                applicationGroups[index] = zLoaderAppGroupID
            } else {
                applicationGroups.append(zLoaderAppGroupID)
            }
        }
        verboseLog("[FetchProvisioningProfiles] Application groups: \(applicationGroups)")
        
        var seenGroupIDs = Set<String>()
        
        do {
            let appGroups = try await TaskChainCoalescer.shared.coalesce(key: "fetch_app_groups_\(team.identifier)") {
                if let cachedGroups = self.context.sharedContext.appGroups {
                    self.debugLog("[FetchProvisioningProfiles] Using cached App Groups from shared context.")
                    return cachedGroups
                }
                self.debugLog("[FetchProvisioningProfiles] Fetching existing App Groups from Apple for team \(team.identifier)...")
                let fetched = try await DeveloperPortalProxy.shared.fetchAppGroups(for: team)
                self.context.sharedContext.appGroups = fetched
                self.verboseLog("[FetchProvisioningProfiles] Found \(fetched.count) existing App Groups on portal for team \(team.identifier): \(fetched.map { $0.groupIdentifier })")
                return fetched
            }
            self.verboseLog("[FetchProvisioningProfiles] Active App Groups for team \(team.identifier): \(appGroups.map { $0.groupIdentifier })")
            
            var groups = [ALTAppGroup]()
            
            for groupIdentifier in applicationGroups {
                let adjustedGroupIdentifier = try await self.adjustedGroupIdentifier(for: groupIdentifier, appID: appID, targetAppBundle: targetAppBundle, team: team)
                guard seenGroupIDs.insert(adjustedGroupIdentifier).inserted else { continue }
                
                let group: ALTAppGroup
                if let existing = self.context.sharedContext.appGroups?.first(where: { $0.groupIdentifier == adjustedGroupIdentifier }) {
                    group = existing
                } else {
                    // Not all characters are allowed in group names, so we replace periods with spaces (like Apple does).
                    let name = "zLoader " + groupIdentifier.replacingOccurrences(of: ".", with: " ")
                    do {
                        group = try await TaskChainCoalescer.shared.coalesce(key: "add_app_group_\(adjustedGroupIdentifier)") {
                            // skip add if already added into shared by other tasks
                            if let existing = self.context.sharedContext.appGroups?.first(where: { $0.groupIdentifier == adjustedGroupIdentifier }) {
                                return existing
                            }
                            let newGroup = try await DeveloperPortalProxy.shared.addAppGroup(name: name, groupIdentifier: adjustedGroupIdentifier, team: team)
                            self.context.sharedContext.appendAppGroup(newGroup)
                            self.verboseLog("[FetchProvisioningProfiles] Created new App Group \(newGroup.groupIdentifier).")
                            return newGroup
                        }
                    } catch {
                        self.debugLog("[FetchProvisioningProfiles] Failed to create new App Group \(adjustedGroupIdentifier). \(error.localizedDescription)")
                        throw error
                    }
                }
                groups.append(group)
            }
            
            try await DeveloperPortalProxy.shared.assignAppID(appID, to: Array(groups), team: team)
            let groupIDs = groups.map { $0.groupIdentifier }
            self.debugLog("[FetchProvisioningProfiles] Assigned App ID \(appID.bundleIdentifier) to App Groups \(groupIDs.description).")
            
            return (appID, groupIDs)
        } catch {
            let groupIDs = Array(seenGroupIDs.isEmpty ? Set(applicationGroups.map { $0 + "." + team.identifier }) : seenGroupIDs)
            self.debugLog("[FetchProvisioningProfiles] Failed to assign/create App Groups \(groupIDs) for App ID \(appID.bundleIdentifier): \(error.localizedDescription)")
            throw error
        }
    }

    func adjustedGroupIdentifier(for groupIdentifier: String, appID: ALTAppID, targetAppBundle: ALTApplication, team: ALTTeam) async throws -> String {
        if groupIdentifier.hasSuffix("." + team.identifier) ||
            self.context.sharedContext.appGroups?.contains(where: { $0.groupIdentifier == groupIdentifier }) == true {
            return groupIdentifier
        }

        let rawGroupID = groupIdentifier.hasPrefix("group.") ? String(groupIdentifier.dropFirst("group.".count)) : groupIdentifier
        let targetBundleID = targetAppBundle.bundleIdentifier
        let contextTargetBundleID = self.context.targetBundleIdentifier
        
        let matchesBundleID = rawGroupID.caseInsensitiveCompare(targetBundleID) == .orderedSame ||
                              rawGroupID.caseInsensitiveCompare(contextTargetBundleID) == .orderedSame
        let isExactCaseMatch = rawGroupID == targetBundleID || rawGroupID == contextTargetBundleID

        if matchesBundleID && !isExactCaseMatch {
            let correctedGroup = "group." + appID.bundleIdentifier
            let originalGroupWithTeam = groupIdentifier + "." + team.identifier
            
            if UserDefaults.standard.autoFixAppGroupIDs {
                return correctedGroup
            } else {
                let decision = try await self.context.handler.userCustomizationHandler.resolveAppGroupMismatch(
                    originalGroup: originalGroupWithTeam,
                    correctedGroup: correctedGroup
                )
                switch decision {
                case .correctAndProceed(let group):
                    return group
                case .keepOriginal(let group):
                    return group
                }
            }
        }

        return groupIdentifier + "." + team.identifier
    }
}

private extension FetchProvisioningProfilesOperation {
    func sanitizeAppIDName(name: String, bundleIdentifier: String) -> String {
        let sanitizedName = self.sanitizeToAscii(name)
        if !sanitizedName.isEmpty {
            return sanitizedName
        }

        return self.sanitizeToAscii(bundleIdentifier)
    }

    func sanitizeToAscii(_ string: String) -> String {
        let romanized = string.applyingTransform(.toLatin, reverse: false) ?? string

        let asciiConverted: String
        if let icuTransliterated = romanized.applyingTransform(StringTransform("Latin-ASCII"), reverse: false) {
            asciiConverted = icuTransliterated
        } else if let lossyData = romanized.data(using: .ascii, allowLossyConversion: true),
                  let lossyString = String(data: lossyData, encoding: .ascii) {
            asciiConverted = lossyString
        } else {
            asciiConverted = romanized
        }

        var result = ""
        result.reserveCapacity(min(asciiConverted.utf8.count, 50))
        var lastWasSpace = true

        for scalar in asciiConverted.unicodeScalars {
            if result.count >= 50 { break }

            if (scalar.value >= 0x30 && scalar.value <= 0x39) ||
               (scalar.value >= 0x41 && scalar.value <= 0x5A) ||
               (scalar.value >= 0x61 && scalar.value <= 0x7A) {
                result.unicodeScalars.append(scalar)
                lastWasSpace = false
            } else if !lastWasSpace {
                result.append(" ")
                lastWasSpace = true
            }
        }

        if lastWasSpace, !result.isEmpty {
            result.removeLast()
        }

        return result
    }
}
