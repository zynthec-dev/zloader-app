import Foundation

@main struct AppValidityTests {
    static func main() {
        let host = Date(timeIntervalSince1970: 1000)
        let earlier = host.addingTimeInterval(-100)
        let later = host.addingTimeInterval(100)
        precondition(AppValidity.expiration(host: host, extensions: [], certificate: nil) == host)
        precondition(AppValidity.expiration(host: host, extensions: [earlier, later], certificate: later) == earlier)
        precondition(AppValidity.expiration(host: host, extensions: [later], certificate: earlier) == earlier)
        precondition(AppValidity.remainingDays(until: host, now: host) == 0)
        precondition(AppValidity.remainingDays(until: earlier, now: host) == 0)
        precondition(AppValidity.remainingDays(until: later, now: host) == 1)
        precondition(AppValidity.remainingDays(until: host.addingTimeInterval(365 * 86_400 - 10), now: host) == 365)
        precondition(AppValidity.remainingDays(until: host.addingTimeInterval(7 * 86_400 - 10), now: host) == 7)
        precondition(AppValidity.remainingDays(until: host.addingTimeInterval(364 * 86_400), now: host) == 364)
        let profiles = ["app.widget": earlier, "app": host]
        precondition(AppValidity.hostProfile(in: profiles, identifiers: ["app"], allowSingleProfile: false) == host)
        precondition(AppValidity.hostProfile(in: profiles, identifiers: ["missing"], allowSingleProfile: true) == nil)
        precondition(AppValidity.hostProfile(in: ["wildcard": host], identifiers: ["app"], allowSingleProfile: true) == host)
        precondition(AppValidity.hostProfile(in: ["app.widget": earlier], identifiers: ["app"], allowSingleProfile: false) == nil)
        print("PASS host profile selection, wildcard fallback and earliest host/extension/certificate expiry")
    }
}
