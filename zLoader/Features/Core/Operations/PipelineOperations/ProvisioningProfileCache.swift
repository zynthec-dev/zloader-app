import Foundation
import SideSign

enum ProvisioningProfileCache {
    /// Keep refreshed authorization beside the cached app, without exporting an
    /// IPA. Only call after the device accepted profile installation.
    static func write(_ profiles: [String: ALTProvisioningProfile], for app: InstalledApp) throws {
        let directory = app.directoryURL.appendingPathComponent("ProvisioningProfiles", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (identifier, profile) in profiles {
            let filename = profile.bundleIdentifier.contains("*") ? identifier : profile.bundleIdentifier
            guard !filename.isEmpty, !filename.contains("/"), !filename.contains("\\") else {
                throw OperationError.invalidParameters("Invalid provisioning profile cache identifier.")
            }
            try profile.data.write(to: directory.appendingPathComponent(filename + ".mobileprovision"), options: .atomic)
        }
    }
}
