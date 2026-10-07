import AppIntents
import Foundation
import CoreData

struct JITAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Installed App"
    static var defaultQuery = JITAppQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct JITAppQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [JITAppEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [JITAppEntity] {
        try await DatabaseManager.shared.start()
        return await DatabaseManager.shared.persistentContainer.performBackgroundTask { context in
            InstalledApp.fetchActiveApps(in: context).filter { $0.bundleIdentifier != StoreApp.zloaderAppID }
                .map { JITAppEntity(id: $0.bundleIdentifier, name: $0.name) }
        }
    }
}

struct EnableJITIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable JIT"
    static var description = IntentDescription("Enables JIT for an already running app using the configured device tunnel and pairing. The operation runs in the background when iOS allows it.")
    static var supportedModes: IntentModes { [.background] }
    static var openAppWhenRun = false
    @Parameter(title: "App") var app: JITAppEntity
    static var parameterSummary: some ParameterSummary { Summary("Enable JIT for \(\.$app)") }

    @MainActor func perform() async throws -> some IntentResult {
        do {
            try await DatabaseManager.shared.start()
            guard let installed = InstalledApp.first(satisfying: NSPredicate(format: "bundleIdentifier == %@", app.id), in: DatabaseManager.shared.viewContext) else {
                throw OperationError.invalidParameters(NSLocalizedString("The selected app is no longer installed.", comment: ""))
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                AppManager.shared.enableJIT(for: installed) { result in continuation.resume(with: result) }
            }
            return .result()
        } catch {
            throw IntentError(error)
        }
    }
}
