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
        var requested = app
        requested.features[.networkExtensions] = "false"
        requested.features[.associatedDomains] = "true"
        requested.features[.appGroups] = " TRUE "
        requested.features[.siri] = "false"
        let changes = requested.changedFeatures(comparedTo: app)
        precondition(changes.count == 2)
        precondition(changes[.networkExtensions] == "false")
        precondition(changes[.associatedDomains] == "true")
        precondition(changes[Feature(rawValue: "numeric")] == nil)
        precondition(app.changedFeatures(comparedTo: app).isEmpty)
        // Apple may alter an unrelated flag in readback. Only requested changes
        // determine whether the mutation was confirmed.
        var confirmed = requested
        confirmed.features[Feature(rawValue: "numeric")] = "3"
        var expectedReadback = confirmed
        expectedReadback.features.merge(changes) { _, requested in requested }
        precondition(expectedReadback.changedFeatures(comparedTo: confirmed).isEmpty)
        confirmed.features[.networkExtensions] = "true"
        precondition(Set(expectedReadback.changedFeatures(comparedTo: confirmed).keys) == Set([.networkExtensions]))
        var memory = app
        memory.features[.increasedMemoryLimit] = "true"
        memory.features[.extendedVirtualAddressing] = "true"
        memory.features[.increasedDebuggingMemoryLimit] = "false"
        memory.features[.associatedDomains] = "true"
        let wire = memory.capabilityUpdateParameters(comparedTo: app)
        precondition(wire["increasedMemoryLimit"] == nil)
        precondition(wire["extendedVirtualAddressing"] == nil)
        precondition(wire[Feature.associatedDomains.rawValue] as? Bool == true)
        let entitlementValues = wire["entitlements"] as! [String: any Sendable]
        precondition(entitlementValues[Entitlement.increasedMemoryLimit.rawValue] as? Bool == true)
        precondition(entitlementValues[Entitlement.extendedVirtualAddressing.rawValue] as? Bool == true)
        var disabledMemory = memory
        disabledMemory.features[.increasedMemoryLimit] = "false"
        let disabling = disabledMemory.capabilityUpdateParameters(comparedTo: memory)
        let disabledValues = disabling["entitlements"] as! [String: any Sendable]
        precondition(disabledValues[Entitlement.increasedMemoryLimit.rawValue] as? Bool == false)
        let encoded = try PropertyListSerialization.data(fromPropertyList: wire, format: .xml, options: 0)
        let decoded = try PropertyListSerialization.propertyList(from: encoded, format: nil) as! [String: Any]
        precondition((decoded["entitlements"] as? [String: Any])?[Entitlement.increasedMemoryLimit.rawValue] as? Bool == true)
        print("PASS: mixed Apple capability values, absent features and invalid responses")
    }
}
