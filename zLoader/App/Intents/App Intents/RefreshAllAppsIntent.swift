//
//  RefreshAllAppsIntent.swift
//  ZLoader
//
//  Created by Riley Testut on 8/18/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import AppIntents

// Shouldn't conform types we don't own to protocols we don't own, so make custom
// NSError subclass that conforms to CustomLocalizedStringResourceConvertible instead.
//
// Would prefer to just conform ALTLocalizedError to CustomLocalizedStringResourceConvertible,
// but that can't be done without raising minimum version for ALTLocalizedError to iOS 16 :/
@available(iOS 16, tvOS 16, *)
class IntentError: NSError, CustomLocalizedStringResourceConvertible, @unchecked Sendable
{
    var localizedStringResource: LocalizedStringResource {
        return "\(self.localizedDescription)"
    }

    init(_ error: some Error)
    {
        let serializedError = (error as NSError).sanitizedForSerialization()
        super.init(domain: serializedError.domain, code: serializedError.code, userInfo: serializedError.userInfo)
    }

    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }
}

@available(iOS 17.0, tvOS 17.0, *)
struct InstallIPAIntent: AppIntent, ProgressReportingIntent
{
    static var title: LocalizedStringResource = "Install IPA"
    static var description = IntentDescription("Installs an IPA file with zLoader.")
    static var openAppWhenRun = false

    @Parameter(title: "IPA File")
    var ipaFile: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Install \(\.$ipaFile)")
    }

    init()
    {
        self.progress.completedUnitCount = 0
        self.progress.totalUnitCount = 1
    }

    func perform() async throws -> some IntentResult
    {
        do
        {
            try await DatabaseManager.shared.start()

            let temporaryDirectory = FileManager.default.uniqueTemporaryURL()
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

            let ipaURL = temporaryDirectory.appendingPathComponent("App.ipa")
            try self.ipaFile.data.write(to: ipaURL)

            let intentProgress = self.progress
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InstalledApp, Error>) in
                let group = AppManager.shared.install(.url(ipaURL)) { result in
                    continuation.resume(with: result)
                }
                intentProgress.addChild(group.progress, withPendingUnitCount: 1)
            }

            return .result()
        }
        catch
        {
            let intentError = IntentError(error)
            throw intentError
        }
    }
}


@available(iOS 17.0, tvOS 17.0, *)
struct RefreshAllAppsIntent: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent, ProgressReportingIntent
{
    static let intentClassName = "RefreshAllIntent"

    static var title: LocalizedStringResource = "Refresh All Apps"
    static var description = IntentDescription("Refreshes your sideloaded apps to prevent them from expiring.")

    static var parameterSummary: some ParameterSummary {
        Summary("Refresh All Apps")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction {
            DisplayRepresentation(
                title: "Refresh All Apps",
                subtitle: ""
            )
        }
    }

    let presentsNotifications: Bool

    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    init(presentsNotifications: Bool)
    {
        self.presentsNotifications = presentsNotifications

        self.progress.completedUnitCount = 0
        self.progress.totalUnitCount = 1
    }

    init()
    {
        self.init(presentsNotifications: false)
    }

    func perform() async throws -> some IntentResult & ProvidesDialog
    {
        do
        {
            // Bring long-running device work forward before it starts; completion
            // follows the operation itself rather than a guessed timeout.
            if systemContext.currentMode.canContinueInForeground
            {
                try await continueInForeground()
            }
            try await self.refreshAllApps()

            return .result(dialog: "All apps have been refreshed.")
        }
        catch
        {
            let intentError = IntentError(error)
            throw intentError
        }
    }
}

@available(iOS 17.0, tvOS 17.0, *)
private extension RefreshAllAppsIntent
{
    func refreshAllApps() async throws
    {
        try await DatabaseManager.shared.start()

        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        let installedApps = await context.perform { InstalledApp.fetchAppsForRefreshingAll(in: context) }

        try await withCheckedThrowingContinuation { continuation in
            do
            {
                let operation = try AppManager.shared.backgroundRefresh(installedApps, presentsNotifications: self.presentsNotifications) { (result) in
                    do
                    {
                        let results = try result.get()

                        for (_, result) in results
                        {
                            guard case let .failure(error) = result else { continue }
                            throw error
                        }

                        continuation.resume()
                    }
                    catch OperationError.noInstalledApps
                    {
                        continuation.resume()
                    }
                    catch
                    {
                        continuation.resume(throwing: error)
                    }
                }

                operation.ignoresServerNotFoundError = false
                self.progress.addChild(operation.progress, withPendingUnitCount: 1)
            }
            catch
            {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum ShortcutOperationOutcome: String, AppEnum {
    case succeeded, failed, cancelled
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Operation Outcome"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .succeeded: "Succeeded", .failed: "Failed", .cancelled: "Cancelled"
    ]
    static func forError(_ error: Error) -> Self {
        if error is CancellationError { return .cancelled }
        return .failed
    }
}

/// Returns the operation outcome instead of throwing a routine operation error,
/// allowing a following Shortcuts VPN-disconnect action to run on failure too.
struct InstallIPAWithOutcomeIntent: AppIntent, ProgressReportingIntent {
    static var title: LocalizedStringResource = "Install IPA with Outcome"
    static var description = IntentDescription("Signs and installs an IPA, waits for completion and returns Succeeded, Failed or Cancelled. Connect your VPN before this action and disconnect it afterwards.")
    static var supportedModes: IntentModes { [.foreground(.immediate)] }
    @Parameter(title: "IPA File") var ipaFile: IntentFile
    static var parameterSummary: some ParameterSummary { Summary("Install \(\.$ipaFile) with outcome") }

    func perform() async throws -> some IntentResult & ReturnsValue<ShortcutOperationOutcome> & ProvidesDialog {
        do {
            try await DatabaseManager.shared.start()
            let folder = FileManager.default.uniqueTemporaryURL()
            defer { try? FileManager.default.removeItem(at: folder) }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("App.ipa")
            try ipaFile.data.write(to: url)
            progress.totalUnitCount = 1
            let intentProgress = progress
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InstalledApp, Error>) in
                let group = AppManager.shared.install(.url(url)) { continuation.resume(with: $0) }
                intentProgress.addChild(group.progress, withPendingUnitCount: 1)
            }
            return .result(value: ShortcutOperationOutcome.succeeded, dialog: "Installation complete.")
        } catch {
            return .result(value: ShortcutOperationOutcome.forError(error), dialog: "Installation ended: \(error.localizedDescription)")
        }
    }
}

struct RefreshAllWithOutcomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh All Apps with Outcome"
    static var description = IntentDescription("Waits for all refresh operations and returns Succeeded, Failed or Cancelled. Connect your VPN before this action and disconnect it afterwards.")
    static var supportedModes: IntentModes { [.foreground(.immediate)] }
    func perform() async throws -> some IntentResult & ReturnsValue<ShortcutOperationOutcome> & ProvidesDialog {
        do {
            try await RefreshAllAppsIntent(presentsNotifications: false).refreshAllApps()
            return .result(value: ShortcutOperationOutcome.succeeded, dialog: "Refresh complete.")
        } catch {
            return .result(value: ShortcutOperationOutcome.forError(error), dialog: "Refresh ended: \(error.localizedDescription)")
        }
    }
}
