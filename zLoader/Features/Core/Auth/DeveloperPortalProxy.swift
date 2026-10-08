//
//  DeveloperPortalProxy.swift
//  ZLoader
//
//  Created by Magesh K on 2026-06-29.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import SideSign

public class DeveloperPortalProxy {
    public static let shared: DeveloperPortalProxy = DeveloperPortalProxyWithAuth()
    
    public static var currentDeviceType: ALTDeviceType {
        #if os(tvOS)
        return .tv
        #elseif os(visionOS)
        return .vision
        #elseif os(watchOS)
        return .watch
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
    }
    
    fileprivate init() {}
    
    private func getSession() async throws -> ALTAppleAPISession {
        try await AuthManager.shared.getAuthenticatedSession()
    }

    private func getTeam(_ team: ALTTeam? = nil) async throws -> ALTTeam {
        if let team { return team }
        return try await AuthManager.shared.getAuthenticatedTeam()
    }
    
    public func fetchTeams(for account: ALTAccount) async throws -> [ALTTeam] {
        let session = try await self.getSession()
        return try await ALTAppleAPI.shared.fetchTeams(for: account, session: session)
    }
    
    public func fetchCertificates(team: ALTTeam? = nil) async throws -> [ALTX509Certificate] {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.fetchCertificates(for: team, session: session)
    }
    
    @discardableResult
    public func createCertificate(machineName: String, type: CertificateType = .development, team: ALTTeam? = nil) async throws -> ALTCertificate {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.addCertificate(machineName: machineName, type: type, to: team, session: session)
    }
    
    @discardableResult
    public func revokeCertificate(_ certificate: ALTX509Certificate, team: ALTTeam? = nil) async throws -> Bool {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        guard try await ALTAppleAPI.shared.revokeCertificate(certificate, for: team, session: session) else { throw PortalMutationError.rejected }
        return true
    }
    
    public func fetchDevices(for team: ALTTeam? = nil, types: ALTDeviceType = .all) async throws -> [ALTDevice] {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.fetchDevices(for: team, types: types, session: session)
    }
    
    @discardableResult
    public func registerDevice(name: String, identifier: String, type: ALTDeviceType = DeveloperPortalProxy.currentDeviceType, team: ALTTeam? = nil) async throws -> ALTDevice {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.registerDevice(name: name, identifier: identifier, type: type, team: team, session: session)
    }

    @discardableResult
    public func updateDevice(_ device: ALTDevice, team: ALTTeam? = nil) async throws -> ALTDevice {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.updateDevice(device, team: team, session: session)
    }

    @discardableResult
    public func disableDevice(_ device: ALTDevice, team: ALTTeam? = nil) async throws -> ALTDevice {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.disableDevice(device, team: team, session: session)
    }

    @discardableResult
    public func deleteDevice(_ device: ALTDevice, team: ALTTeam? = nil) async throws -> Bool {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        guard try await ALTAppleAPI.shared.deleteDevice(device, team: team, session: session) else { throw PortalMutationError.rejected }
        let remaining = try await ALTAppleAPI.shared.fetchDevices(for: team, types: .all, session: session)
        guard !remaining.contains(where: { $0.identifier == device.identifier }) else { throw PortalMutationError.notConfirmed }
        return true
    }

    public func fetchAppIDs(team: ALTTeam? = nil) async throws -> [ALTAppID] {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.fetchAppIDs(for: team, session: session)
    }

    public func fetchAppIDs(for team: ALTTeam) async throws -> [ALTAppID] {
        try await self.fetchAppIDs(team: team)
    }

    @discardableResult
    public func addAppID(name: String, bundleIdentifier: String, team: ALTTeam? = nil) async throws -> ALTAppID {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.addAppID(withName: name, bundleIdentifier: bundleIdentifier, team: team, session: session)
    }

    @discardableResult
    public func updateAppID(_ appID: ALTAppID, team: ALTTeam? = nil, requireFeatureReadback: Bool = true) async throws -> ALTAppID {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        let before = try await ALTAppleAPI.shared.fetchAppIDs(for: team, session: session)
        guard let current = before.first(where: { $0.identifier == appID.identifier }) else {
            throw PortalMutationError.updateNotConfirmed
        }
        let changes = appID.changedFeatures(comparedTo: current)
        let rename = appID.name != current.name
        guard !changes.isEmpty || rename else { return current }
        let accepted = try await ALTAppleAPI.shared.updateAppID(appID, team: team, session: session)
        // Signing verifies the Apple-signed profile, which is authoritative for
        // entitlements. The service flag list does not expose every entitlement.
        // Portal editors retain strict readback; Apple's mutation errors still throw.
        if !requireFeatureReadback { return accepted }
        var missing = changes.keys.map(\.rawValue).sorted()
        // Read back only requested deltas. Read-only/unchanged flags can differ
        // between Apple's list and mutation responses and are not write failures.
        for _ in 0..<3 {
            let fresh = try await ALTAppleAPI.shared.fetchAppIDs(for: team, session: session)
            guard let confirmed = fresh.first(where: { $0.identifier == appID.identifier }) else { continue }
            var desired = confirmed
            desired.features.merge(changes) { _, requested in requested }
            missing = desired.changedFeatures(comparedTo: confirmed).keys.map(\.rawValue).sorted()
            if missing.isEmpty && (!rename || confirmed.name == appID.name) { return confirmed }
        }
        if missing.isEmpty { throw PortalMutationError.updateNotConfirmed }
        throw PortalMutationError.capabilitiesNotConfirmed(missing)
    }

    @discardableResult
    public func deleteAppID(_ appID: ALTAppID, team: ALTTeam? = nil) async throws -> Bool {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        guard try await ALTAppleAPI.shared.deleteAppID(appID, for: team, session: session) else { throw PortalMutationError.rejected }
        let remaining = try await ALTAppleAPI.shared.fetchAppIDs(for: team, session: session)
        guard !remaining.contains(where: { $0.identifier == appID.identifier }) else { throw PortalMutationError.notConfirmed }
        return true
    }

    @discardableResult
    public func deleteAppID(_ appID: ALTAppID, for team: ALTTeam) async throws -> Bool {
        try await self.deleteAppID(appID, team: team)
    }

    public func fetchAppGroups(team: ALTTeam? = nil) async throws -> [ALTAppGroup] {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.fetchAppGroups(for: team, session: session)
    }

    public func fetchAppGroups(for team: ALTTeam) async throws -> [ALTAppGroup] {
        try await self.fetchAppGroups(team: team)
    }

    @discardableResult
    public func addAppGroup(name: String, groupIdentifier: String, team: ALTTeam? = nil) async throws -> ALTAppGroup {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.addAppGroup(name: name, groupIdentifier: groupIdentifier, team: team, session: session)
    }

    @discardableResult
    public func updateAppGroup(_ group: ALTAppGroup, team: ALTTeam? = nil) async throws -> ALTAppGroup {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        _ = try await ALTAppleAPI.shared.updateAppGroup(group, team: team, session: session)
        let fresh = try await ALTAppleAPI.shared.fetchAppGroups(for: team, session: session)
        guard let confirmed = fresh.first(where: { $0.groupID == group.groupID }),
              confirmed.name == group.name else { throw PortalMutationError.updateNotConfirmed }
        return confirmed
    }

    @discardableResult
    public func assignAppID(_ appID: ALTAppID, to groups: [ALTAppGroup], team: ALTTeam? = nil) async throws -> ALTAppID {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        // Group assignment does not enable the App Groups capability itself.
        // Enable and verify that permission before sending the association request.
        var target = appID
        if !groups.isEmpty && target.features[.appGroups]?.lowercased() != "true" {
            target.features[.appGroups] = "true"
            target = try await updateAppID(target, team: team)
        }
        return try await ALTAppleAPI.shared.assign(target, to: groups, team: team, session: session)
    }

    @discardableResult
    public func assign(_ appID: ALTAppID, to groups: [ALTAppGroup], team: ALTTeam? = nil) async throws -> ALTAppID {
        try await self.assignAppID(appID, to: groups, team: team)
    }

    @discardableResult
    public func deleteAppGroup(_ group: ALTAppGroup, team: ALTTeam? = nil) async throws -> Bool {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        guard try await ALTAppleAPI.shared.deleteAppGroup(group, team: team, session: session) else { throw PortalMutationError.rejected }
        let remaining = try await ALTAppleAPI.shared.fetchAppGroups(for: team, session: session)
        guard !remaining.contains(where: { $0.identifier == group.identifier || $0.groupID == group.groupID }) else { throw PortalMutationError.notConfirmed }
        return true
    }

    public func listProvisioningProfiles(includeTeamProfiles: Bool = true, team: ALTTeam? = nil) async throws -> [ALTListedProvisioningProfile] {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.listProvisioningProfiles(includeTeamProfiles: includeTeamProfiles, for: team, session: session)
    }

    public func downloadProvisioningProfile(for appID: ALTAppID, isTeamProfile: Bool = true, deviceType: ALTDeviceType = DeveloperPortalProxy.currentDeviceType, team: ALTTeam? = nil) async throws -> ALTProvisioningProfile {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.downloadProvisioningProfile(for: appID, isTeamProfile: isTeamProfile, deviceType: deviceType, team: team, session: session)
    }

    public func downloadProvisioningProfile(for appID: ALTAppID, isTeamProfile: Bool = true, type: ALTProfileType, team: ALTTeam? = nil) async throws -> ALTProvisioningProfile {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.downloadProvisioningProfile(for: appID, isTeamProfile: isTeamProfile, type: type, team: team, session: session)
    }

    public func downloadProvisioningProfile(profileID: String, team: ALTTeam? = nil) async throws -> ALTProvisioningProfile {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.downloadProvisioningProfile(profileID: profileID, team: team, session: session)
    }

    public func createProvisioningProfile(name: String, appID: ALTAppID, certificateIDs: [String], deviceIDs: [String], team: ALTTeam? = nil) async throws -> ALTProvisioningProfile {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        #if os(tvOS)
        let subPlatform: String? = "tvOS"
        #else
        let subPlatform: String? = nil
        #endif
        return try await ALTAppleAPI.shared.createProvisioningProfile(name: name, appID: appID, certificateIDs: certificateIDs, deviceIDs: deviceIDs, subPlatform: subPlatform, team: team, session: session)
    }

    public func createProvisioningProfile(name: String, appID: ALTAppID, certificateIDs: [String], deviceIDs: [String] = [], type: ALTProfileType, team: ALTTeam? = nil) async throws -> ALTProvisioningProfile {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.createProvisioningProfile(name: name, appID: appID, certificateIDs: certificateIDs, deviceIDs: deviceIDs, type: type, team: team, session: session)
    }

    public func updateProvisioningProfile(profileID: String, name: String, appIDId: String, certificateIDs: [String], deviceIDs: [String], team: ALTTeam? = nil) async throws -> ALTProvisioningProfile {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        #if os(tvOS)
        let subPlatform: String? = "tvOS"
        #else
        let subPlatform: String? = nil
        #endif
        return try await ALTAppleAPI.shared.updateProvisioningProfile(profileID: profileID, name: name, appIDId: appIDId, certificateIDs: certificateIDs, deviceIDs: deviceIDs, subPlatform: subPlatform, team: team, session: session)
    }

    public func updateProvisioningProfile(profileID: String, name: String, appIDId: String, certificateIDs: [String], deviceIDs: [String] = [], type: ALTProfileType, team: ALTTeam? = nil) async throws -> ALTProvisioningProfile {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        return try await ALTAppleAPI.shared.updateProvisioningProfile(profileID: profileID, name: name, appIDId: appIDId, certificateIDs: certificateIDs, deviceIDs: deviceIDs, type: type, team: team, session: session)
    }

    @discardableResult
    public func deleteProvisioningProfile(profileID: String, team: ALTTeam? = nil) async throws -> Bool {
        let session = try await self.getSession()
        let team = try await self.getTeam(team)
        guard try await ALTAppleAPI.shared.deleteProvisioningProfile(profileID: profileID, team: team, session: session) else { throw PortalMutationError.rejected }
        let remaining = try await ALTAppleAPI.shared.listProvisioningProfiles(includeTeamProfiles: true, for: team, session: session)
        guard !remaining.contains(where: { $0.identifier == profileID }) else { throw PortalMutationError.notConfirmed }
        return true
    }
}

class DeveloperPortalProxyWithAuth: DeveloperPortalProxy {
    fileprivate override init() {
        super.init()
    }

    func fetchAccount(session: ALTAppleAPISession) async throws -> ALTAccount {
        try await ALTAppleAPI.shared.fetchAccount(session: session)
    }

    func signIn(appleID: String, 
                password: String, 
                anisetteData: ALTAnisetteData, 
                xcodeVersion: String, 
                machinePassword: String? = nil,
                accountRepairHandler: DeveloperPortal.AccountRepairHandler = DeveloperPortal.defaultAccountRepairHandler,
                verificationHandler: DeveloperPortal.VerificationHandler?) async throws -> (ALTAccount, ALTAppleAPISession) 
    {
        let authSession = try await ALTAppleAPI.shared.authenticate(
            appleID: appleID,
            password: password,
            anisetteData: anisetteData,
            xcodeVersion: xcodeVersion,
            machinePassword: machinePassword,
            accountRepairHandler: accountRepairHandler,
            verificationHandler: verificationHandler
        )
        return (authSession.account, authSession.session)
    }
}

/// A mutation is successful only after Apple accepts it and fresh remote state
/// confirms it. Local lists must remain unchanged on rejection/uncertainty.
enum PortalMutationError: LocalizedError {
    case rejected, notConfirmed, updateNotConfirmed
    case capabilitiesNotConfirmed([String])
    var errorDescription: String? {
        switch self {
        case .capabilitiesNotConfirmed(let features):
            return NSLocalizedString("Apple did not confirm these capability changes:", comment: "") + " " + features.joined(separator: ", ")
        case .updateNotConfirmed: return NSLocalizedString("Apple did not confirm the requested changes. Your edits were kept. Refresh the Developer Portal and try again.", comment: "")
        case .rejected: return NSLocalizedString("Apple rejected the portal change. No local item was removed.", comment: "")
        case .notConfirmed: return NSLocalizedString("Apple still lists this item after the request. The change could not be confirmed; refresh the portal and try again. The local item was preserved.", comment: "")
        }
    }
}
