import Foundation
import CoreData
import SideSign

/// The installing team owns the store's installed identity. Signing unrelated
/// apps with another account must not replace the store's profiles/App Groups.
enum SelfRefreshPolicy {
    static let installedTeam = ALTApplication(fileURL: Bundle.main.bundleURL)?.provisioningProfile?.teamIdentifier

    static func canRefresh(in context: NSManagedObjectContext) -> Bool {
        guard let installedTeam, let selected = DatabaseManager.shared.activeTeam(in: context) else { return false }
        return selected.identifier == installedTeam
    }

    static var protectedMessage: String {
        NSLocalizedString("This zLoader installation is signed by a different team. Its provisioning profiles are preserved and it is excluded from refresh. Other apps can use your selected Apple Account.", comment: "")
    }
}
