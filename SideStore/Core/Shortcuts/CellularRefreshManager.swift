import Foundation
import Minimuxer

/// Upstream-compatible preference facade. zLoader never toggles system cellular
/// settings or launches Shortcuts. Device transport is owned by operation leases.
public final class CellularRefreshManager: @unchecked Sendable {
    public static let shared = CellularRefreshManager()
    private init() {}
    public var isEnabled: Bool { UserDefaults.standard.isCellularRefreshEnabled }
    public var isCellularMode: Bool { isEnabled && !minimuxer.network.isWifiSatisfied }
    public func setEnabled(_ enabled: Bool) { UserDefaults.standard.isCellularRefreshEnabled = enabled }
}
