import Foundation
import UIKit
import SideSign

/// Owns an editable, private copy. No portal writes occur until Sign is pressed.
final class SignIPAPreparation: @unchecked Sendable {
    let context: InstallAppOperationContext
    let team: ALTTeam
    let certificate: ALTCertificate
    let importedProfiles: [ALTProvisioningProfile]?
    init(context: InstallAppOperationContext, team: ALTTeam, certificate: ALTCertificate, profiles: [ALTProvisioningProfile]?) {
        self.context = context
        self.team = team
        self.certificate = certificate
        importedProfiles = profiles
    }
    deinit { try? FileManager.default.removeItem(at: context.temporaryDirectory) }
}

/// Sign-only never writes InstalledApp records or launches installation.
enum SignIPAService {
    static func prepare(_ source: URL, identity: ImportedSigningIdentity?,
                        customization: SigningCustomizationOptions? = nil) async throws -> SignIPAPreparation {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let certificate: ALTCertificate
        let profiles: [ALTProvisioningProfile]?
        let team: ALTTeam
        if let identity {
            (certificate, profiles) = try await MainActor.run {
                guard let key = CertificateManager.shared.getLocalCertificate(serialNumber: identity.certificateSerial) else {
                    throw OperationError.invalidParameters(NSLocalizedString("The imported certificate or its private key is missing.", comment: ""))
                }
                let values = try identity.profileIDs.map { id in
                    guard let profile = ProfileManager.shared.getProfile(uuid: id) else {
                        throw OperationError.invalidParameters(NSLocalizedString("An assigned provisioning profile is missing. Import it again.", comment: ""))
                    }
                    return profile
                }
                return (key, values)
            }
            guard let first = profiles?.first else {
                throw OperationError.invalidParameters(NSLocalizedString("Import at least one provisioning profile.", comment: ""))
            }
            team = ALTTeam(identifier: first.teamIdentifier, name: first.teamName, type: first.isFreeProvisioningProfile ? .free : .individual)
        } else {
            team = try await AuthManager.shared.getAuthenticatedTeam()
            guard let active = await MainActor.run(body: { CertificateManager.shared.activeCertificate?.certificate }) else {
                throw OperationError.invalidParameters(NSLocalizedString("Select an active signing certificate for your Apple Account first.", comment: ""))
            }
            certificate = active
            profiles = nil
        }
        guard certificate.expiryDate > Date(), let certificateData = certificate.data else {
            throw OperationError.invalidParameters(NSLocalizedString("The signing certificate is expired or unreadable.", comment: ""))
        }
        try PortablePKCS12.validate(certificate: certificateData, key: certificate.privateKey)
        let fm = FileManager.default
        let temporary = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temporary) }
        let appURL = try fm.unzipAppBundle(at: source, to: temporary)
        guard let app = ALTApplication(fileURL: appURL) else {
            throw OperationError.invalidApp(reason: NSLocalizedString("The IPA does not contain a readable app bundle.", comment: ""))
        }
        let handler = PipelineHandler(presenterProvider: { UIApplication.shared.topViewController() })
        let context = InstallAppOperationContext(pipelineSteps: [], bundleIdentifier: app.bundleIdentifier,
            dbBackgroundContext: DatabaseManager.shared.persistentContainer.newBackgroundContext(),
            sharedContext: SharedPipelineContext(), handler: handler, activeSigningCertificate: certificate)
        context.isSignOnly = true
        context.signingTeamOverride = team
        context.appendTeamID = identity == nil
        context.embedSigningCertificate = false
        context.includeAllRegisteredDevices = true
        let prepared = SignIPAPreparation(context: context, team: team, certificate: certificate, profiles: profiles)
        let copy = context.temporaryDirectory.appendingPathComponent("Editable.app")
        try fm.copyItem(at: appURL, to: copy)
        guard let target = ALTApplication(fileURL: copy) else { throw OperationError.invalidApp(reason: "Invalid app copy") }
        context.targetAppBundle = target
        if let customization {
            _ = try await RemoveAppExtensionsOperation(context: context, localAppExtensions: nil, customization: customization.extensions).execute(parentProgress: nil)
            // Reload after extensions are removed; ALTApplication caches its children.
            context.targetAppBundle = ALTApplication(fileURL: copy)
            _ = try await UserCustomizationOperation(context: context, options: customization).execute(parentProgress: nil)
            _ = try await ChangeAppIconOperation(context: context).execute(parentProgress: nil)
            let plistKey = context.customInfoPlistByBundleID[context.targetBundleIdentifier] != nil ? context.targetBundleIdentifier : app.bundleIdentifier
            if customization.icon, context.alternateIconURL != nil,
               var plist = context.customInfoPlistByBundleID[plistKey],
               let updated = ALTApplication(fileURL: copy) {
                for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
                    plist[key] = updated.infoPlist[key]
                }
                context.customInfoPlistByBundleID[plistKey] = plist
            }
            context.targetAppBundle = ALTApplication(fileURL: copy)
            context.installedApp = nil
        }
        return prepared
    }

    static func sign(_ source: URL, identity: ImportedSigningIdentity?) async throws -> URL {
        try await sign(prepare(source, identity: identity))
    }

    static func sign(_ preparation: SignIPAPreparation) async throws -> URL {
        let context = preparation.context
        guard let app = context.targetAppBundle else { throw OperationError.invalidApp(reason: "Missing app") }
        if let profiles = preparation.importedProfiles {
            var chosen: [String: ALTProvisioningProfile] = [:]
            for component in [app] + app.appExtensions {
                let targetID = component.bundleIdentifier == app.bundleIdentifier ? context.targetBundleIdentifier :
                    component.bundleIdentifier.replacingOccurrences(of: app.bundleIdentifier, with: context.targetBundleIdentifier)
                let requested = context.customEntitlementsByBundleID[targetID] ?? context.customEntitlementsByBundleID[component.bundleIdentifier] ?? component.entitlements
                let candidates = ([context.overrideProvisioningProfile].compactMap { $0 } + profiles).filter {
                    $0.expirationDate > Date() && $0.teamIdentifier == preparation.team.identifier &&
                    $0.certificates.contains(where: { $0.rawDER == preparation.certificate.certificate.rawDER }) &&
                    SigningEntitlements.matchesBundleIdentifier($0.bundleIdentifier, bundleIdentifier: targetID)
                }.sorted { $0.bundleIdentifier.count > $1.bundleIdentifier.count }
                guard let matched = candidates.first(where: {
                    (try? SigningEntitlements.prepare(application: requested, profile: $0.entitlements,
                        teamID: preparation.team.identifier, bundleIdentifier: targetID)) != nil
                }) else {
                    throw OperationError.invalidParameters(String(format: NSLocalizedString("No compatible profile authorizes %@, this certificate and every requested entitlement.", comment: ""), targetID))
                }
                chosen[targetID] = matched
            }
            context.provisioningProfiles = chosen
            // Imported profiles must authorize every extension independently.
            context.useMainProfile = false
        } else {
            context.provisioningProfiles = try await ZLoaderTransport.withLease {
                try await FetchProvisioningProfilesOperation(context: context).execute(parentProgress: nil)
            }
        }
        for component in [app] + app.appExtensions {
            let archive = component.fileURL.appendingPathComponent("ALTCertificate.p12")
            if FileManager.default.fileExists(atPath: archive.path) { try FileManager.default.removeItem(at: archive) }
        }
        try Task.checkCancellation()
        let signed = try await ResignAppOperation(context: context).execute(parentProgress: nil)
        return try saveToLibrary(signed.fileURL)
    }

    private static func saveToLibrary(_ appURL: URL) throws -> URL {
        try Task.checkCancellation()
        let fm = FileManager.default
        let result = try fm.zipAppBundle(at: appURL)
        let library = CacheManager.shared.resignedAppsDirectory
        try fm.createDirectory(at: library, withIntermediateDirectories: true)
        let name = ALTApplication(fileURL: appURL)?.name ?? "App"
        let safeName = name.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        let target = library.appendingPathComponent(safeName + "-" + UUID().uuidString + ".ipa")
        try fm.moveItem(at: result, to: target)
        return target
    }
}
