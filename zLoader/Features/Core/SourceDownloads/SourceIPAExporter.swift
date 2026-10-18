@preconcurrency import UIKit
import CoreData

@MainActor final class SourceIPAExporter: NSObject {
    static let shared = SourceIPAExporter()
    private var isBusy = false
    private var exportDirectory: URL?
    private struct Busy: LocalizedError {
        var errorDescription: String? { NSLocalizedString("Finish the current IPA export first.", comment: "") }
    }

    func export(_ app: StoreApp, from presenter: UIViewController) async throws {
        guard !isBusy else { throw Busy() }
        guard let version = app.latestAvailableVersion ?? app.versions.first else { return }
        let request = SourceIPADownloadRequest(url: version.downloadURL, name: app.name,
                                               version: version.version, sha256: version.sha256)
        isBusy = true
        do {
            let file = try await SourceIPAFile.download(request)
            exportDirectory = file.deletingLastPathComponent()
            guard presenter.viewIfLoaded?.window != nil else { finish(); return }
            #if !os(tvOS)
            let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
            picker.delegate = self
            presenter.present(picker, animated: true)
            #else
            TVWebFileTransferManager.shared.startExport(fileURL: file, title: "Export IPA", presentingVC: presenter)
            isBusy = false
            #endif
        } catch {
            finish()
            throw error
        }
    }

    private func finish() {
        if let exportDirectory { try? FileManager.default.removeItem(at: exportDirectory) }
        exportDirectory = nil
        isBusy = false
    }
}

#if !os(tvOS)
extension SourceIPAExporter: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish() }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finish() }
}
#endif

@MainActor enum SourceAppAccess {
    static func canInstall(_ app: StoreApp) -> Bool {
        guard let identifier = app.source?.identifier else { return false }
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        return context.performAndWait {
            let request = Source.fetchRequest()
            request.predicate = NSPredicate(format: "%K == %@", #keyPath(Source.identifier), identifier)
            return ((try? context.count(for: request)) ?? 0) > 0
        }
    }

    static func requireSource(_ app: StoreApp, from presenter: UIViewController?) -> Bool {
        guard !canInstall(app) else { return true }
        let alert = UIAlertController(title: NSLocalizedString("Add Source First", comment: ""),
            message: NSLocalizedString("Add this source to install its apps. You can download the IPA without adding the source.", comment: ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        presenter?.present(alert, animated: true)
        return false
    }
}
