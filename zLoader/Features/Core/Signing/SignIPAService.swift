import Foundation
import SideSign

/// Sign-only never writes InstalledApp records or launches installation.
enum SignIPAService {
    static func sign(_ source: URL, identity: ImportedSigningIdentity?) async throws -> URL {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        let temporary = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temporary) }
        let appURL = try fm.unzipAppBundle(at: source, to: temporary)
        guard let app = ALTApplication(fileURL: appURL) else { throw OperationError.invalidApp(reason: NSLocalizedString("The IPA does not contain a readable app bundle.", comment: "")) }
        var managedContext: InstallAppOperationContext?
        defer { if let managedContext { try? fm.removeItem(at: managedContext.temporaryDirectory) } }
        let certificate: ALTCertificate
        let profiles: [ALTProvisioningProfile]
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
            guard let first = profiles.first else { throw OperationError.invalidParameters(NSLocalizedString("Import at least one provisioning profile.", comment: "")) }
            team = ALTTeam(identifier: first.teamIdentifier, name: first.teamName, type: first.isFreeProvisioningProfile ? .free : .individual)
        } else {
            team = try await AuthManager.shared.getAuthenticatedTeam()
            guard let active = await MainActor.run(body: { CertificateManager.shared.activeCertificate?.certificate }) else {
                throw OperationError.invalidParameters(NSLocalizedString("Select an active signing certificate for your Apple Account first.", comment: ""))
            }
            certificate = active
            let context = InstallAppOperationContext(pipelineSteps: [], bundleIdentifier: app.bundleIdentifier,
                dbBackgroundContext: DatabaseManager.shared.persistentContainer.newBackgroundContext(),
                sharedContext: SharedPipelineContext(), handler: PipelineHandler(), activeSigningCertificate: certificate)
            context.targetAppBundle = app
            context.appendTeamID = true
            context.embedSigningCertificate = false
            context.includeAllRegisteredDevices = true
            let issued = try await ZLoaderTransport.withLease {
                try await FetchProvisioningProfilesOperation(context: context).execute(parentProgress: nil)
            }
            context.provisioningProfiles = issued
            managedContext = context
            profiles = Array(issued.values)
        }
        guard certificate.expiryDate > Date(), let certificateData = certificate.data else {
            throw OperationError.invalidParameters(NSLocalizedString("The signing certificate is expired or unreadable.", comment: ""))
        }
        try PortablePKCS12.validate(certificate: certificateData, key: certificate.privateKey)
        // The installation resign step resolves the original app/extension IDs to
        // their issued profile IDs and updates plist references and entitlements.
        // Applying profiles directly to the original IDs would reject team-suffixed IDs.
        for component in [app] + app.appExtensions {
            let archive = component.fileURL.appendingPathComponent("ALTCertificate.p12")
            if fm.fileExists(atPath: archive.path) { try fm.removeItem(at: archive) }
        }
        if let managedContext {
            let signed = try await ResignAppOperation(context: managedContext).execute(parentProgress: nil)
            return try saveToLibrary(signed.fileURL)
        }
        var chosen: [ALTProvisioningProfile] = []
        for component in [app] + app.appExtensions {
            let candidates = profiles.filter {
                $0.expirationDate > Date() && $0.teamIdentifier == team.identifier &&
                $0.certificates.contains(where: { $0.rawDER == certificate.certificate.rawDER }) &&
                SigningEntitlements.matchesBundleIdentifier($0.bundleIdentifier, bundleIdentifier: component.bundleIdentifier)
            }.sorted { $0.bundleIdentifier.count > $1.bundleIdentifier.count }
            var matched: ALTProvisioningProfile?
            for candidate in candidates {
                if (try? SigningEntitlements.prepare(application: component.entitlements,
                    profile: candidate.entitlements, teamID: team.identifier, bundleIdentifier: component.bundleIdentifier)) != nil {
                    matched = candidate
                    break
                }
            }
            guard let matched else {
                throw OperationError.invalidParameters(String(format: NSLocalizedString("No compatible profile authorizes %@, this certificate and every requested entitlement.", comment: ""), component.bundleIdentifier))
            }
            chosen.append(matched)
        }
        try Task.checkCancellation()
        try await AppBundleSigner(team: team, keyStore: certificate).signApp(at: appURL, provisioningProfiles: chosen)
        try Task.checkCancellation()
        return try saveToLibrary(appURL)
    }

    private static func saveToLibrary(_ appURL: URL) throws -> URL {
        try Task.checkCancellation()
        let fm = FileManager.default
        let result = try fm.zipAppBundle(at: appURL)
        let library = CacheManager.shared.resignedAppsDirectory
        try fm.createDirectory(at: library, withIntermediateDirectories: true)
        let target = library.appendingPathComponent(appURL.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString + ".ipa")
        try fm.moveItem(at: result, to: target)
        return target
    }
}
