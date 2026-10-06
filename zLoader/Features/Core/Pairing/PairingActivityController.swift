import ActivityKit
import UIKit

@MainActor final class PairingActivityController {
    static let shared = PairingActivityController()
    private var activity: Activity<PairingActivityAttributes>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var updateTask: Task<Void, Never>?
    func start(onExpiration: @escaping @MainActor () -> Void) {
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "zLoader Local Pairing") {
                Task { @MainActor in onExpiration() }
            }
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled, activity == nil else { return }
        if let existing = Activity<PairingActivityAttributes>.activities.first {
            activity = existing
            update(status: "Warte auf Verbindung", pin: nil)
            return
        }
        do {
            activity = try Activity.request(attributes: PairingActivityAttributes(), content: ActivityContent(state: .init(status: "Warte auf Verbindung", pin: nil, complete: false), staleDate: nil), pushType: nil)
        } catch { debugLog("[PairingActivity] Live Activity unavailable: \(error.localizedDescription)") }
    }
    func update(status: String, pin: String?) {
        let predecessor = updateTask
        let activity = activity
        updateTask = Task {
            await predecessor?.value
            await activity?.update(ActivityContent(state: .init(status: status, pin: pin, complete: false), staleDate: nil))
        }
    }
    func finish(status: String, success: Bool) {
        let predecessor = updateTask
        let activity = activity
        self.activity = nil
        updateTask = Task {
            await predecessor?.value
            await activity?.end(ActivityContent(state: .init(status: status, pin: nil, complete: success), staleDate: nil), dismissalPolicy: .immediate)
        }
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
