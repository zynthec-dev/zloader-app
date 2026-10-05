import Foundation

@main struct AppGroupResolverTests {
    static func main() {
        let base = "group.com.zynthec.zLoader"
        func resolve(_ declared: [String], allowed: Set<String>) -> String? {
            AppGroupResolver.resolve(declared: declared, preferred: [base], isAccessible: allowed.contains)
        }
        precondition(resolve([base], allowed: [base]) == base)
        precondition(resolve([base + ".TEAM"], allowed: [base + ".TEAM"]) == base + ".TEAM")
        precondition(resolve(["group.signer.changed"], allowed: ["group.signer.changed"]) == "group.signer.changed")
        precondition(resolve([base], allowed: []) == nil)
        precondition(resolve([], allowed: [base]) == nil)
        precondition(resolve(["group.a", "group.b"], allowed: ["group.a", "group.b"]) == nil)
        precondition(resolve([base, "group.other"], allowed: ["group.other"]) == nil)
        precondition(resolve([base, base], allowed: [base]) == base)
        precondition(resolve([base + ".TEAM1", base + ".TEAM2"], allowed: [base + ".TEAM1", base + ".TEAM2"]) == nil)
        // Prefix collision must not override the preferred real group.
        precondition(resolve([base, base + "Unrelated"], allowed: [base, base + "Unrelated"]) == base)
        print("PASS App Group authorization, signer rename, ambiguity, deduplication and prefix boundaries (10 cases)")
    }
}
