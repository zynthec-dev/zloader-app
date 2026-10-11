import Foundation

/// The earliest authorization expiry limits how long the whole app can run.
enum AppValidity {
    static func expiration(host: Date, extensions: [Date], certificate: Date?) -> Date {
        ([host] + extensions + [certificate].compactMap { $0 }).min() ?? host
    }

    static func hostProfile<T>(in profiles: [String: T], identifiers: [String], allowSingleProfile: Bool) -> T? {
        for identifier in identifiers {
            if let profile = profiles[identifier] { return profile }
        }
        return allowSingleProfile && profiles.count == 1 ? profiles.values.first : nil
    }
}
