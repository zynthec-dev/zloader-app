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
            context.appendTeamID = false
            context.includeAllRegisteredDevices = true
            profiles = try await ZLoaderTransport.withLease {
                Array(try await FetchProvisioningProfilesOperation(context: context).execute(parentProgress: nil).values)
            }
        }
        guard certificate.expiryDate > Date(), let certificateData = certificate.data else {
            throw OperationError.invalidParameters(NSLocalizedString("The signing certificate is expired or unreadable.", comment: ""))
        }
        try PortablePKCS12.validate(certificate: certificateData, key: certificate.privateKey)
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
        // Old zLoader archives may contain an embedded signing-key export.
        // Strip it before signing so the resource seal matches the safe output.
        for component in [app] + app.appExtensions {
            let keyArchive = component.fileURL.appendingPathComponent("ALTCertificate.p12")
            if fm.fileExists(atPath: keyArchive.path) { try fm.removeItem(at: keyArchive) }
        }
        try Task.checkCancellation()
        try await AppBundleSigner(team: team, keyStore: certificate).signApp(at: appURL, provisioningProfiles: chosen)
        try Task.checkCancellation()
        let result = try fm.zipAppBundle(at: appURL)
        let library = CacheManager.shared.resignedAppsDirectory
        try fm.createDirectory(at: library, withIntermediateDirectories: true)
        let target = library.appendingPathComponent(appURL.deletingPathExtension().lastPathComponent + "-" + UUID().uuidString + ".ipa")
        try fm.moveItem(at: result, to: target)
        return target
    }
}
