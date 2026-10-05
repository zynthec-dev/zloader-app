import Foundation

actor Probe {
    var starts = 0
    var stops = 0
    var shouldFail = false
    var gate: CheckedContinuation<Void, Never>?
    var hold = false
    enum Failure: Error { case startup }
    func start() async throws {
        starts += 1
        if hold { await withCheckedContinuation { gate = $0 } }
        if shouldFail { throw Failure.startup }
    }
    func stop() { stops += 1 }
    func configure(hold: Bool = false, fail: Bool = false) { self.hold = hold; shouldFail = fail }
    func unblock() { gate?.resume(); gate = nil }
    func counts() -> (Int, Int) { (starts, stops) }
    func waiting() -> Bool { gate != nil }
}

@main struct TransportLeaseTests {
    static func main() async throws {
        let probe = Probe()
        let leases = TransportLeaseCoordinator(start: { try await probe.start() }, stop: { await probe.stop() })
        let first = try await leases.acquire()
        let second = try await leases.acquire()
        let check1 = await awaitCounts(probe, expected: (1, 0))
        precondition(check1)
        await leases.release(first)
        await leases.release(first) // stale / duplicate cleanup must not stop another user
        let check2 = await awaitCounts(probe, expected: (1, 0))
        precondition(check2)
        await leases.release(second)
        await leases.waitForTeardown()
        let check3 = await awaitCounts(probe, expected: (1, 1))
        precondition(check3)
        print("PASS overlapping users and idempotent release")

        await probe.configure(hold: true)
        let pending = Task { try await leases.acquire() }
        while !(await probe.waiting()) { await Task.yield() }
        pending.cancel()
        do { _ = try await pending.value; fatalError("Cancellation was swallowed") } catch is CancellationError {}
        await probe.unblock()
        await leases.waitForTeardown()
        let check4 = await awaitCounts(probe, expected: (2, 2))
        precondition(check4)
        print("PASS cancellation during startup cleans up")

        await probe.configure(fail: true)
        do { _ = try await leases.acquire(); fatalError("Failure was swallowed") } catch Probe.Failure.startup {}
        await leases.waitForTeardown()
        let check5 = await awaitCounts(probe, expected: (3, 3))
        precondition(check5)
        await probe.configure()
        let recovered = try await leases.acquire()
        await leases.release(recovered)
        await leases.waitForTeardown()
        let check6 = await awaitCounts(probe, expected: (4, 4))
        precondition(check6)
        print("PASS startup failure and subsequent recovery")

        // A new operation may arrive immediately after final release.
        let before = try await leases.acquire()
        await leases.release(before)
        let after = try await leases.acquire()
        await leases.release(after)
        await leases.waitForTeardown()
        let check7 = await awaitCounts(probe, expected: (6, 6))
        precondition(check7)
        print("PASS teardown / next-start serialization")
    }

    static func awaitCounts(_ probe: Probe, expected: (Int, Int)) async -> Bool {
        let actual = await probe.counts()
        return actual == expected
    }
}
