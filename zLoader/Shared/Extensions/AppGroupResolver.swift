import Foundation

/// Selects only a declared App Group that iOS permits this process to open.
/// A signer may rename a single group; branding is not an authorization check.
enum AppGroupResolver {
    static func resolve(declared: [String], preferred: [String], isAccessible: (String) -> Bool) -> String? {
        let groups = Array(Set(declared)).sorted()
        for prefix in preferred {
            let matching = groups.filter { $0 == prefix || $0.hasPrefix(prefix + ".") }
            guard !matching.isEmpty else { continue }
            let accessible = matching.filter(isAccessible)
            if accessible.contains(prefix) { return prefix }
            // Do not choose between multiple databases or switch away from a
            // declared preferred group that iOS refuses to authorize.
            return accessible.count == 1 ? accessible[0] : nil
        }
        guard groups.count == 1, let group = groups.first, isAccessible(group) else { return nil }
        return group
    }
}
