import UIKit

/// UIKit owns the expiration callback. Both expiration and normal completion
/// end this token on the main actor, including expiration during startup.
@MainActor
final class BackgroundOperationTask {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        let token = identifier
        identifier = .invalid
        UIApplication.shared.endBackgroundTask(token)
    }
}
