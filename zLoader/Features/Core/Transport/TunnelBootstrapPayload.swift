import Foundation
import SideSign

/// The external-VPN IPA carries the provider as inert ZIP data. It becomes an
/// executable extension only in a staged copy, before Apple's provisioning and
/// signing checks. This neither activates a capability nor changes the running app.
enum TunnelBootstrapPayload {
    static let requestKey = "zLoader.provisionInternalTunnel"
    static let pendingKey = "zLoader.tunnelUpgradePending"

    static func prepare(_ app: ALTApplication) throws -> ALTApplication {
        guard app.isZLoaderApp else { return app }
        let hasProvider = app.appExtensions.contains { PacketTunnelProvisioning.isProvider($0.infoPlist) }
        let runningHasProvider = ALTApplication(fileURL: Bundle.Info.activeBundleURL)?.appExtensions.contains {
            PacketTunnelProvisioning.isProvider($0.infoPlist)
        } == true
        guard !hasProvider, UserDefaults.standard.bool(forKey: requestKey) || runningHasProvider else { return app }
        let resource = app.fileURL.appendingPathComponent("zLoaderTunnelPayload.zip")
        let manifestURL = app.fileURL.appendingPathComponent("zLoaderTunnelPayload.plist")
        guard FileManager.default.fileExists(atPath: resource.path) else {
            throw OperationError.invalidParameters("The tunnel payload is missing. Install the current bootstrap IPA and retain all resources.")
        }
        let manifest: TunnelPayloadManifest
        do {
            manifest = try TunnelPayloadManifest(data: Data(contentsOf: manifestURL))
            try manifest.validate(archive: Data(contentsOf: resource),
                                  version: app.infoPlist["CFBundleShortVersionString"] as? String,
                                  build: app.infoPlist["CFBundleVersion"] as? String)
        } catch {
            throw OperationError.invalidParameters("The tunnel payload is damaged or does not match this zLoader version. Self-signing was cancelled.")
        }
        let unpacked = app.fileURL.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: unpacked) }
        try FileManager.default.unzipArchive(at: resource, to: unpacked)
        let providerURL = unpacked.appendingPathComponent("zLoaderTunnel.appex")
        guard let provider = ALTApplication(fileURL: providerURL),
              PacketTunnelProvisioning.isProvider(provider.infoPlist),
              provider.infoPlist["CFBundleShortVersionString"] as? String == manifest.version,
              provider.infoPlist["CFBundleVersion"] as? String == manifest.build else {
            throw OperationError.invalidParameters("The tunnel payload does not match this app version.")
        }
        // A sideloading tool may have changed the host ID. Keep the child under
        // that installed parent; profile resolution preserves the same team/ID.
        var info = provider.infoPlist
        info["CFBundleIdentifier"] = app.bundleIdentifier + ".Tunnel"
        try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0)
            .write(to: providerURL.appendingPathComponent("Info.plist"), options: .atomic)
        let plugins = app.fileURL.appendingPathComponent("PlugIns")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: providerURL, to: plugins.appendingPathComponent("zLoaderTunnel.appex"))
        guard let result = ALTApplication(fileURL: app.fileURL),
              result.appExtensions.contains(where: { PacketTunnelProvisioning.isProvider($0.infoPlist) }) else {
            throw OperationError.invalidParameters("The tunnel extension could not be prepared.")
        }
        return result
    }
}
