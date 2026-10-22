import UIKit

/// iOS can reveal a newly installed icon by moving the installer to the
/// background. Restore only an installation that began in the foreground;
/// background refresh and self replacement must never activate the host.
@MainActor final class InstallationForegroundRecovery {
    private let beganActive = UIApplication.shared.applicationState == .active
    private var enteredBackground = false
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                         object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.enteredBackground = true }
        }
    }

    func finish(succeeded: Bool) {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        guard AppInstallationPresentation.shouldRestoreInstaller(
            beganActive: beganActive, enteredBackground: enteredBackground,
            isActive: UIApplication.shared.applicationState == .active, succeeded: succeeded),
              let identifier = Bundle.main.bundleIdentifier else { return }
        ZLoaderAppLauncher.openApplication(withBundleIdentifier: identifier) { success, error in
            if !success { debugLog("[Installation] Could not return to zLoader: \(error?.localizedDescription ?? "Unknown error")") }
        }
    }
}
