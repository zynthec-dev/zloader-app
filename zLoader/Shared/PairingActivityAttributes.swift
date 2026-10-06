#if os(iOS)
import ActivityKit

struct PairingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var pin: String?
        var complete: Bool
    }
    var name: String = "zLoader"
}
#endif
