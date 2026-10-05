import Foundation

/// Shares a transport across overlapping operations. The final release, rather
/// than elapsed time, owns teardown. Kept independent of iOS for concurrency tests.
actor TransportLeaseCoordinator {
    typealias Action = @Sendable () async throws -> Void
    private let start: Action
    private let stop: @Sendable () async -> Void
    private var users: Set<UUID> = []
    private var waiters: [UUID: CheckedContinuation<UUID, Error>] = [:]
    private var startup: Task<Void, Never>?
    private var teardown: Task<Void, Never>?
    private var generation = UUID()
    private var ready = false

    init(start: @escaping Action, stop: @escaping @Sendable () async -> Void) {
        self.start = start
        self.stop = stop
    }

    func acquire() async throws -> UUID {
        let id = UUID()
        users.insert(id)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                guard users.contains(id) else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if ready {
                    continuation.resume(returning: id)
                    return
                }
                waiters[id] = continuation
                if startup == nil {
                    let previousTeardown = teardown
                    let current = UUID()
                    generation = current
                    startup = Task {
                        await previousTeardown?.value
                        do {
                            try Task.checkCancellation()
                            try await start()
                            try Task.checkCancellation()
                            didStart(current, error: nil)
                        } catch {
                            didStart(current, error: error)
                        }
                    }
                }
            }
        } onCancel: {
            Task { await self.release(id) }
        }
    }

    private func didStart(_ current: UUID, error: Error?) {
        guard generation == current else { return }
        if let error {
            let pending = waiters
            waiters.removeAll()
            users.removeAll()
            scheduleStop()
            for continuation in pending.values { continuation.resume(throwing: error) }
        } else {
            ready = true
            let pending = waiters
            waiters.removeAll()
            for (id, continuation) in pending { continuation.resume(returning: id) }
        }
    }

    func release(_ id: UUID) {
        guard users.remove(id) != nil else { return }
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
        if users.isEmpty { scheduleStop() }
    }

    private func scheduleStop() {
        ready = false
        generation = UUID()
        let pendingStart = startup
        pendingStart?.cancel()
        startup = nil
        let previous = teardown
        let stop = self.stop
        teardown = Task {
            await previous?.value
            await pendingStart?.value
            await stop()
        }
    }

    func waitForTeardown() async { await teardown?.value }
}
