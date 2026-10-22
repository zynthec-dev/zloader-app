import Foundation
@main struct AppInstallationPresentationTests {
    static func main() {
        for beganActive in [false, true] {
            for backgrounded in [false, true] {
                for isActive in [false, true] {
                    for succeeded in [false, true] {
                        precondition(AppInstallationPresentation.shouldRestoreInstaller(beganActive: beganActive,
                            enteredBackground: backgrounded, isActive: isActive, succeeded: succeeded) ==
                            (beganActive && backgrounded && !isActive && succeeded))
                    }
                }
            }
        }
        let order = ["expires-today", "running-store", "expires-next-week", "other-store"]
        precondition(AppInstallationPresentation.pinnedFirst(order) { $0 == "running-store" } == ["running-store", "expires-today", "expires-next-week", "other-store"])
        precondition(AppInstallationPresentation.pinnedFirst(order) { $0 == "missing" } == order)
        precondition(AppInstallationPresentation.pinnedFirst([String]()) { $0 == "running-store" }.isEmpty)
        for target in ["other-store", "youtube.music", "running-store.backup", ""] {
            precondition(!AppInstallationPresentation.isSelfReplacement(runningBundleID: "running-store", resignedBundleID: target))
        }
        precondition(!AppInstallationPresentation.isSelfReplacement(runningBundleID: "", resignedBundleID: ""))
        precondition(AppInstallationPresentation.isSelfReplacement(runningBundleID: "running-store", resignedBundleID: "running-store"))
        print("PASS running store pinned first without disturbing other ordering; only exact running bundle identity permits self-replacement")
    }
}
