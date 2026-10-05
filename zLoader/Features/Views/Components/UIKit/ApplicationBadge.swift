import UIKit
import UserNotifications

@MainActor
func setApplicationBadge(_ count: Int) {
    #if !os(tvOS)
    if #available(iOS 17, *) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error { debugLog("[zLoader] Could not update badge: \(error)") }
        }
    } else {
        setLegacyApplicationBadge(count)
    }
    #endif
}

@MainActor
@available(iOS, introduced: 15, deprecated: 17)
private func setLegacyApplicationBadge(_ count: Int) {
    UIApplication.shared.applicationIconBadgeNumber = count
}
