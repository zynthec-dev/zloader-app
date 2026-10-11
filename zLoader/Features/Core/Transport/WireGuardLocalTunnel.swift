import Foundation
import Minimuxer

/// Loopback WireGuard peer only. The external WireGuard app owns the VPN profile.
actor WireGuardLocalTunnel {
    static let shared = WireGuardLocalTunnel()
    static let selectionKey = "zLoader.externalWireGuard"
    private var startTask: Task<Void, Error>?
    private var running = false

    func prepare() async throws {
        guard UserDefaults.standard.bool(forKey: Self.selectionKey) else { return }
        #if os(iOS) && !targetEnvironment(simulator)
        if running { return }
        if let startTask { return try await startTask.value }
        let task = Task {
            minimuxer.emproxy.setHandshakeClient(host: "10.7.0.1", port: 62078, enabled: true)
            try await minimuxer.emproxy.start(host: "127.0.0.1", port: 51820)
        }
        startTask = task
        do {
            try await task.value
            running = true
            startTask = nil
        } catch {
            startTask = nil
            throw error
        }
        #endif
    }

    func stop() async throws {
        if let startTask {
            try await startTask.value
            running = true
        }
        guard running else { return }
        try await minimuxer.emproxy.stop()
        running = false
        startTask = nil
    }

    func exportConfiguration() async throws -> URL {
        let cache = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WireGuard", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let cachedFile = cache.appendingPathComponent("LocalTunnel.conf")
        let data: Data
        if let cached = try? Data(contentsOf: cachedFile), let valid = try? WireGuardConfiguration.validated(cached) {
            data = valid
        } else {
            var request = URLRequest(url: WireGuardConfiguration.sourceURL)
            request.timeoutInterval = 30
            let (download, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw WireGuardConfiguration.Failure.invalidConfiguration }
            data = try WireGuardConfiguration.validated(download)
            try data.write(to: cachedFile, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WireGuard-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let exported = directory.appendingPathComponent("zLoader-Local-Tunnel.conf")
        try data.write(to: exported, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return exported
    }
}
