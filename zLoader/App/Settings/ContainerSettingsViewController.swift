import UIKit
import SideSign

final class ContainerSettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Container"
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Identität übernehmen", style: .plain,
            target: self, action: #selector(importSelectedIdentity))
    }

    @objc private func importSelectedIdentity() {
        do {
            let material = try SigningIdentityStore.shared.selectedMaterial()
            guard let certificate = material?.certificate ?? CertificateManager.shared.activeCertificate?.certificate,
                  let hostProfile = ALTApplication(fileURL: Bundle.main.bundleURL)?.provisioningProfile,
                  hostProfile.certificates.contains(where: { $0.rawDER == certificate.certificate.rawDER }),
                  certificate.expiryDate > Date() else {
                throw OperationError.invalidParameters("Wähle eine gültige Signieridentität, die auch zLoader signiert hat. Signiere zLoader bei Bedarf zuerst mit dieser Identität neu. Alternativ kannst du JIT verwenden, sofern es für dein System unterstützt wird.")
            }
            let password = UUID().uuidString
            let data = try CertificateManager.convert(certificate, password: password)
            var storageError: NSError?
            guard ZLoaderSetContainerSigningIdentity(data, password, &storageError) else {
                throw storageError ?? OperationError.invalidParameters("Die Container-Signieridentität konnte nicht gespeichert werden.") as NSError
            }
            NotificationCenter.default.post(name: .init("ZLoaderContainerIdentityChanged"), object: nil)
            showMessage("Die ausgewählte Identität wurde im Schlüsselbund für die Container-Signierung hinterlegt.")
        } catch { showMessage(error.localizedDescription) }
    }
    private func showMessage(_ text: String) {
        let alert = UIAlertController(title: "Container-Signierung", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
