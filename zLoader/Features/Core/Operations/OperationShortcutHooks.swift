import UIKit
import Combine

/// Foreground URL callbacks, not system automation triggers. Serializes groups
/// while hooks are enabled so one group's cleanup cannot disconnect another.
@MainActor
final class OperationShortcutHooks: ObservableObject {
    static let shared = OperationShortcutHooks()
    struct Session: Sendable {
        let id: UUID
        let apps: [String]
        let finish: String
    }
    @Published private(set) var waitingName: String?
    private var active: UUID?
    private var callbackID: UUID?
    private var callback: CheckedContinuation<Void, Error>?
    static let beforeKey = "zLoader.shortcuts.beforeOperation"
    static let afterKey = "zLoader.shortcuts.afterOperation"

    func begin(apps: [String]) async throws -> Session? {
        if UserDefaults.standard.bool(forKey: "zLoader.useInternalVPN") { return nil }
        let before = UserDefaults.standard.string(forKey: Self.beforeKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let after = UserDefaults.standard.string(forKey: Self.afterKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !apps.isEmpty, !before.isEmpty || !after.isEmpty else { return nil }
        guard active == nil else { throw OperationError.invalidParameters("An operation with shortcut hooks is already running. Wait for it to finish.") }
        let session = Session(id: UUID(), apps: apps, finish: after)
        active = session.id
        do {
            if !before.isEmpty { try await run(before, event: "before", apps: apps) }
            return session
        } catch {
            await end(session, outcome: error is CancellationError ? "cancelled" : "failed")
            throw error
        }
    }

    func end(_ session: Session?, outcome: String) async {
        guard let session, active == session.id else { return }
        defer { active = nil }
        guard !session.finish.isEmpty else { return }
        do {
            // A cancelled operation still needs a cleanup attempt. This task
            // does not inherit its caller's cancellation state.
            try await Task { @MainActor in
                try await self.run(session.finish, event: outcome, apps: session.apps)
            }.value
        }
        catch { debugLog("[Shortcut hooks] Abschluss-Kurzbefehl nicht abgeschlossen: \(error.localizedDescription)") }
    }

    func handle(_ url: URL) -> Bool {
        guard url.scheme == "zloader", url.host == "operation-shortcut",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idText = parts.queryItems?.first(where: { $0.name == "id" })?.value,
              UUID(uuidString: idText) == callbackID else { return false }
        let result: Result<Void, Error>
        switch url.path {
        case "/success": result = .success(())
        case "/cancel": result = .failure(CancellationError())
        case "/error":
            let message = parts.queryItems?.first(where: { $0.name == "errorMessage" })?.value ?? "Kurzbefehl fehlgeschlagen."
            result = .failure(OperationError.invalidParameters(message))
        default: return false
        }
        finishCallback(result)
        return true
    }

    func cancelWaiting() { finishCallback(.failure(CancellationError())) }

    private func finishCallback(_ result: Result<Void, Error>) {
        let pending = callback
        callback = nil
        callbackID = nil
        waitingName = nil
        pending?.resume(with: result)
    }

    private func run(_ name: String, event: String, apps: [String]) async throws {
        guard UIApplication.shared.applicationState == .active else {
            throw OperationError.invalidParameters("Shortcut hooks require zLoader in the foreground and an unlocked device.")
        }
        try Task.checkCancellation()
        let id = UUID()
        let input = try JSONSerialization.data(withJSONObject: ["event": event, "bundleIdentifiers": apps])
        var url = URLComponents()
        url.scheme = "shortcuts"
        url.host = "x-callback-url"
        url.path = "/run-shortcut"
        url.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "input", value: "text"),
                          URLQueryItem(name: "text", value: String(decoding: input, as: UTF8.self))]
        for (key, path) in [("x-success", "success"), ("x-error", "error"), ("x-cancel", "cancel")] {
            url.queryItems?.append(URLQueryItem(name: key, value: "zloader://operation-shortcut/\(path)?id=\(id.uuidString)"))
        }
        guard let target = url.url else { throw OperationError.invalidParameters("Invalid shortcut request.") }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                callbackID = id
                waitingName = name
                callback = continuation
                UIApplication.shared.open(target) { success in
                    if !success && self.callbackID == id { self.finishCallback(.failure(OperationError.invalidParameters("Shortcuts could not be opened."))) }
                }
            }
        } onCancel: {
            Task { @MainActor in
                if self.callbackID == id { self.finishCallback(.failure(CancellationError())) }
            }
        }
    }
}
