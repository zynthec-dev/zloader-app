import Foundation

@main struct PortalCapabilityGraphTests {
    static func json(_ value: String) throws -> PortalJSON { try JSONDecoder().decode(PortalJSON.self, from: Data(value.utf8)) }
    static func main() throws {
        let metadata = try json("""
        [{"type":"capabilities","id":"CARPLAY_AUDIO","attributes":{"name":"CarPlay Audio","entitlement":"com.apple.developer.carplay-audio","editable":true}},
         {"type":"capabilities","id":"FUTURE_MANAGED_RIGHT","attributes":{"name":"Future Managed Right","editable":true}},
         {"type":"capabilities","id":"RESTRICTED","attributes":{"name":"Restricted","editable":false}},
         {"type":"capabilities","id":"CONFIGURED","attributes":{"name":"Configuration","editable":true,"settings":[{"key":"choice"}]}}]
        """).array!
        let graph = try json("""
        {"data":{"type":"bundleIds","id":"SYNTHETIC","attributes":{"name":"Synthetic app","identifier":"example.test","seedId":"TEST"},"relationships":{"bundleIdCapabilities":{"data":[{"id":"existing","type":"bundleIdCapabilities"}]}}},
         "included":[{"id":"existing","type":"bundleIdCapabilities","attributes":{"enabled":true,"editable":true,"settings":[{"key":"retain","options":[{"key":"value","enabled":true}]}]},"relationships":{"capability":{"data":{"type":"capabilities","id":"UNKNOWN_ENABLED"}},"appGroups":{"data":[{"type":"appGroups","id":"retain-group"}]}}}]}
        """)
        let catalog = try PortalCapabilityGraph.inventory(metadata: metadata, graph: graph, appID: "SYNTHETIC")
        precondition(catalog.count == 5)
        precondition(catalog.first { $0.id == "CARPLAY_AUDIO" }?.editable == true)
        precondition(catalog.first { $0.id == "UNKNOWN_ENABLED" }?.enabled == true)
        precondition(catalog.first { $0.id == "UNKNOWN_ENABLED" }?.editable == false)
        let patch = try PortalCapabilityGraph.patch(metadata: metadata, graph: graph, appID: "SYNTHETIC", capabilityID: "CARPLAY_AUDIO", enabled: true)
        let children = patch["data"]?["relationships"]?["bundleIdCapabilities"]?["data"]?.array ?? []
        precondition(children.count == 2)
        precondition(children[0]["attributes"]?["settings"] == graph["included"]?.array?[0]["attributes"]?["settings"])
        precondition(children[0]["relationships"]?["appGroups"]?["data"] == graph["included"]?.array?[0]["relationships"]?["appGroups"]?["data"])
        precondition(children[1]["relationships"]?["capability"]?["data"]?["id"]?.string == "CARPLAY_AUDIO")
        for id in ["RESTRICTED", "CONFIGURED", "NOT_RETURNED_BY_APPLE"] {
            do { _ = try PortalCapabilityGraph.patch(metadata: metadata, graph: graph, appID: "SYNTHETIC", capabilityID: id, enabled: true); preconditionFailure("unauthorized/configuration-only mutation") }
            catch { }
        }
        do { _ = try PortalCapabilityGraph.inventory(metadata: metadata, graph: graph, appID: "OTHER"); preconditionFailure("wrong app") } catch { }
        let partial = try json("""
        {"data":{"type":"bundleIds","id":"SYNTHETIC","relationships":{"bundleIdCapabilities":{"data":[{"id":"missing","type":"bundleIdCapabilities"}],"links":{"next":"page2"}}}}}
        """)
        do { _ = try PortalCapabilityGraph.patch(metadata: metadata, graph: partial, appID: "SYNTHETIC", capabilityID: "CARPLAY_AUDIO", enabled: true); preconditionFailure("incomplete graph") } catch { }
        print("PASS dynamic CarPlay/unknown capability inventory, Apple edit restrictions, configuration requirements, exact App ID, complete graphs and preservation of unrelated settings/groups")
    }
}
