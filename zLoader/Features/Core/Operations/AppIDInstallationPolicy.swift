import Foundation

/// The free-account registration quota is independent of the active-app limit.
enum AppIDInstallationPolicy {
    static func blocksDeviceInstall(isFreeTeam: Bool, registeredCount: Int?) -> Bool {
        guard isFreeTeam, let registeredCount else { return false }
        return registeredCount >= 10
    }
}
