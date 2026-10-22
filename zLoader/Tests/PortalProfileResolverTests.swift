import Foundation

@main struct PortalProfileResolverTests {
    enum Failure: Error { case offline, unreadable }
    struct Profile { let id: String; let valid: Bool; let sameTeam: Bool }
    final class Portal {
        var profiles = ["old": Profile(id: "old", valid: true, sameTeam: true)]
        var events: [String] = []
        var failList = false
        var failDownload = false
        var owned = true
        func resolve(renewExisting: Bool = false) async throws -> Profile {
            try await PortalProfileResolver.resolve(renewExisting: renewExisting, list: {
                self.events.append("list")
                if self.failList { throw Failure.offline }
                return self.profiles.keys.sorted().map { .init(identifier: $0, mayRenew: self.owned) }
            }, download: { id in
                self.events.append("download:" + id)
                if self.failDownload { throw Failure.unreadable }
                return self.profiles[id]!
            }, compatible: { $0.valid && $0.sameTeam }, renewable: { $0.sameTeam }, renew: { id in
                self.events.append("renew:" + id)
                let profile = Profile(id: id, valid: true, sameTeam: true)
                self.profiles[id] = profile
                return profile
            }, create: {
                self.events.append("create")
                let profile = Profile(id: "new", valid: true, sameTeam: true)
                self.profiles[profile.id] = profile
                return profile
            })
        }
    }
    static func main() async throws {
        let portal = Portal()
        let first = try await portal.resolve()
        precondition(first.id == "old" && portal.events == ["list", "download:old"])
        // Simulate a still-valid local/installed copy after deleting its portal record.
        let installedCopy = first
        portal.profiles.removeValue(forKey: installedCopy.id)
        portal.events = []
        let replacement = try await portal.resolve()
        precondition(installedCopy.valid && replacement.id != installedCopy.id)
        precondition(portal.events == ["list", "create"])
        portal.events = []
        let nextInstall = try await portal.resolve()
        precondition(nextInstall.id == replacement.id && portal.events == ["list", "download:new"])
        for errorMode in [0, 1] {
            let unavailable = Portal()
            unavailable.failList = errorMode == 0; unavailable.failDownload = errorMode == 1
            do { _ = try await unavailable.resolve(); preconditionFailure("Cannot sign using unverified portal state") } catch {}
            precondition(!unavailable.events.contains("create") && !unavailable.events.contains(where: { $0.hasPrefix("renew:") }))
        }
        let expired = Portal()
        expired.profiles["old"] = Profile(id: "old", valid: false, sameTeam: true)
        _ = try await expired.resolve()
        precondition(expired.events == ["list", "download:old", "renew:old"])
        let foreign = Portal()
        foreign.profiles["old"] = Profile(id: "old", valid: false, sameTeam: false)
        _ = try await foreign.resolve()
        precondition(foreign.events == ["list", "download:old", "create"])
        let unowned = Portal(); unowned.owned = false
        unowned.profiles["old"] = Profile(id: "old", valid: false, sameTeam: true)
        _ = try await unowned.resolve()
        precondition(unowned.events == ["list", "download:old", "create"])
        let duplicate = Portal()
        duplicate.profiles["old"] = Profile(id: "old", valid: false, sameTeam: true)
        duplicate.profiles["other"] = Profile(id: "other", valid: true, sameTeam: true)
        _ = try await duplicate.resolve()
        precondition(duplicate.events == ["list", "download:old", "download:other"])
        let refresh = Portal()
        _ = try await refresh.resolve(renewExisting: true)
        precondition(refresh.events == ["list", "download:old", "renew:old"])
        let external = Portal(); external.owned = false
        _ = try await external.resolve(renewExisting: true)
        precondition(external.events == ["list", "download:old", "create"])
        let unavailableRefresh = Portal(); unavailableRefresh.failDownload = true
        do { _ = try await unavailableRefresh.resolve(renewExisting: true); preconditionFailure() } catch {}
        precondition(unavailableRefresh.events == ["list", "download:old"])
        print("PASS fresh portal check every time; deleted profile recreated despite valid installed copy; subsequent reuse; read failures do not create; renewal ownership/team checks; compatible duplicates reused")
    }
}
