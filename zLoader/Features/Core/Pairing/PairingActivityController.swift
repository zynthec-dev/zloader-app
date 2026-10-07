import ActivityKit
import UIKit
import UserNotifications

@MainActor final class PairingActivityController {
    static let shared = PairingActivityController()
    private var activity: Activity<PairingActivityAttributes>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var updateTask: Task<Void, Never>?
    func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString(title, comment: "Pairing notification")
        content.body = NSLocalizedString(body, comment: "Pairing notification")
        content.sound = .default
        content.userInfo = ["zLoaderLocalPairing": true]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "zLoaderLocalPairing", content: content, trigger: nil)) { error in
            if let error { debugLog("[PairingActivity] Notification unavailable: \(error.localizedDescription)") }
        }
    }
    func start(onExpiration: @escaping @MainActor () -> Void) {
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "zLoader Local Pairing") {
                Task { @MainActor in onExpiration() }
            }
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled, activity == nil else { return }
        if let existing = Activity<PairingActivityAttributes>.activities.first {
            activity = existing
            update(status: "Waiting for Connection", pin: nil)
            return
        }
        do {
            activity = try Activity.request(attributes: PairingActivityAttributes(), content: ActivityContent(state: .init(status: "Waiting for Connection", pin: nil, complete: false), staleDate: nil), pushType: nil)
        } catch { debugLog("[PairingActivity] Live Activity unavailable: \(error.localizedDescription)") }
    }
    func update(status: String, pin: String?) {
        if let pin {
            notify(title: String(format: NSLocalizedString("zLoader Pairing Code: %@", comment: ""), pin),
                   body: "Enter this six-digit code in Remote Pairing. Tap to open zLoader.")
        }
        let predecessor = updateTask
        let activity = activity
        updateTask = Task {
            await predecessor?.value
            await activity?.update(ActivityContent(state: .init(status: status, pin: pin, complete: false), staleDate: nil))
        }
    }
    func remotePairingComplete() {
        notify(title: "zLoader · Pairing Complete",
               body: "Remote pairing is saved. Tap to return to zLoader and view the result. Lockdown pairing is configured separately.")
        update(status: "Pairing Complete", pin: nil)
    }
    func finish(status: String, success: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: ["zLoaderLocalPairing"])
        center.removePendingNotificationRequests(withIdentifiers: ["zLoaderLocalPairing"])
        if success {
            notify(title: "zLoader · Pairing Complete", body: "Return to the app. Tap to open zLoader and view the saved pairing status.")
        } else {
            notify(title: "zLoader · Check Pairing", body: status + ". Return to the app to check the status.")
        }
        let predecessor = updateTask
        let activity = activity
        self.activity = nil
        updateTask = Task {
            await predecessor?.value
            await activity?.end(ActivityContent(state: .init(status: status, pin: nil, complete: success), staleDate: nil), dismissalPolicy: success ? .default : .immediate)
        }
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
