import Foundation

/// Presentation changes must not alter refresh-all ordering (the host refreshes last).
enum AppInstallationPresentation {
    static func pinnedFirst<Element>(_ items: [Element], isRunningStore: (Element) -> Bool) -> [Element] {
        guard let index = items.firstIndex(where: isRunningStore), index != items.startIndex else { return items }
        var result = items
        result.insert(result.remove(at: index), at: 0)
        return result
    }

    static func isSelfReplacement(runningBundleID: String, resignedBundleID: String) -> Bool {
        !runningBundleID.isEmpty && runningBundleID == resignedBundleID
    }
}
