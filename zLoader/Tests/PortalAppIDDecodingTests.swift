import Foundation

@main
struct PortalAppIDDecodingTests {
    static func main() throws {
        let mixed = Data(#"{"appIdId":"TESTID","identifier":"com.example.test","features":{"NWEXT04537":true,"APG3427HIY":"true","push":false,"dataProtection":"complete","numeric":2}}"#.utf8)
        let app = try JSONDecoder().decode(AppID.self, from: mixed)
        precondition(app.features[.networkExtensions] == "true")
        precondition(app.features[.appGroups] == "true")
        precondition(app.features[.pushNotifications] == "false")
        precondition(app.features[.dataProtection] == "complete")
        precondition(app.features[Feature(rawValue: "numeric")] == "2")
        let empty = try JSONDecoder().decode(AppID.self, from: Data(#"{"appIdId":"EMPTY"}"#.utf8))
        precondition(empty.features.isEmpty)
        do {
            _ = try JSONDecoder().decode(AppID.self, from: Data(#"{"features":{"push":[]}}"#.utf8))
            fatalError("Unsupported values must not silently clear capability flags")
        } catch is DecodingError { }
        print("PASS: mixed Apple capability values, absent features and invalid responses")
    }
}
