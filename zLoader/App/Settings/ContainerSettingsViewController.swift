import UIKit
import SideSign

final class ContainerSettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Container-Einstellungen"
        navigationItem.largeTitleDisplayMode = .never
        let controller = ZLoaderContainerSettingsController()
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        // Settings remain usable without an identity. Signing reports actionable
        // errors when requested, rather than retaining an obsolete certificate.
        try? ZLoaderContainerHostServices.prepareSigning()
    }
}

/// Called by the embedded runtime without linking it against the host app.
@objc(ZLoaderContainerHostServices)
@MainActor final class ZLoaderContainerHostServices: NSObject {
    private static var preparedCertificate: Data?

    static func prepareSigning() throws {
        #if targetEnvironment(simulator)
        return
        #else
        do {
            let material = try SigningIdentityStore.shared.selectedMaterial()
            guard let certificate = material?.certificate ?? CertificateManager.shared.activeCertificate?.certificate,
                  let profile = ALTApplication(fileURL: Bundle.main.bundleURL)?.provisioningProfile,
                  profile.expirationDate > Date(), certificate.expiryDate > Date(),
                  profile.certificates.contains(where: { $0.rawDER == certificate.certificate.rawDER }) else {
                throw OperationError.invalidParameters("Die aktive Signieridentität muss gültig sein und auch die installierte zLoader-App signiert haben. Signiere zLoader bei Bedarf zuerst mit dieser Identität neu.")
            }
            let der = certificate.certificate.rawDER
            if preparedCertificate == der && ZLoaderContainerSigningAvailable() { return }
            let password = UUID().uuidString
            let data = try CertificateManager.convert(certificate, password: password)
            var error: NSError?
            guard ZLoaderSetContainerSigningIdentity(data, password, &error) else {
                throw error ?? OperationError.invalidParameters("Container-Signieridentität konnte nicht gespeichert werden.") as NSError
            }
            preparedCertificate = der
            NotificationCenter.default.post(name: .init("ZLoaderContainerIdentityChanged"), object: nil)
        } catch {
            preparedCertificate = nil
            ZLoaderClearContainerSigningIdentity()
            throw error
        }
        #endif
    }

    @objc(prepareSigningWithCompletion:)
    static func prepareSigning(completion: @escaping (NSError?) -> Void) {
        do { try prepareSigning(); completion(nil) }
        catch { completion(error as NSError) }
    }

    @objc(enableJITForPID:completion:)
    static func enableJIT(pid: NSNumber, completion: @escaping (NSError?) -> Void) {
        Task {
            do {
                guard pid.intValue > 0, pid.uint64Value <= UInt32.max else {
                    throw OperationError.invalidParameters("Ungültiger Container-Prozess.")
                }
                try await safeAttachDebugger(pid.uint32Value)
                completion(nil)
            } catch { completion(error as NSError) }
        }
    }
}
