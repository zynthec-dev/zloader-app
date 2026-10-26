//
//  InstallAppDialog.swift
//  ZLoader
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit

public enum AppImportSourceMode: String, CaseIterable, Identifiable, Sendable {
    case prompt = "prompt"
    case files  = "files"
    case url    = "url"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .prompt:
            return "Prompt User"
        case .files:
            #if !os(tvOS)
            return "Files App"
            #else
            return "Web Upload"
            #endif
        case .url:
            return "URL"
        }
    }
}

@MainActor
public enum InstallAppDialog {
    
    public static func presentSourceSelection(
        from presentingVC: UIViewController,
        barButtonItem: UIBarButtonItem? = nil,
        mode: AppImportSourceMode = .prompt,
        onChooseFiles: @escaping () -> Void,
        onConfirm: @escaping (URL) -> Void,
        onChooseLibrary: (() -> Void)? = nil
    ) {
        switch mode {
        case .prompt:
            #if !os(tvOS)
            let alertController = UIAlertController(
                title: NSLocalizedString("Install App", tableName: "AppActions", comment: ""),
                message: nil,
                preferredStyle: .actionSheet
            )
            if let popover = alertController.popoverPresentationController {
                popover.barButtonItem = barButtonItem
            }
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Choose from Files", tableName: "AppActions", comment: ""), style: .default) { _ in
                onChooseFiles()
            })
            #else
            let alertController = UIAlertController(
                title: NSLocalizedString("Install App", tableName: "AppActions", comment: ""),
                message: NSLocalizedString("Choose an installation method:", tableName: "AppActions", comment: ""),
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Upload via Web", tableName: "AppActions", comment: ""), style: .default) { _ in
                onChooseFiles()
            })
            #endif
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Install from URL", tableName: "AppActions", comment: ""), style: .default) { _ in
                self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
            })
            if let onChooseLibrary {
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Choose from Library", tableName: "AppActions", comment: ""), style: .default) { _ in onChooseLibrary() })
            }
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", tableName: "AppActions", comment: ""), style: .cancel))
            
            presentingVC.present(alertController, animated: true)

        case .files:
            onChooseFiles()

        case .url:
            self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
        }
    }
    
    private static func presentURLInputDialog(
        from presentingVC: UIViewController,
        onConfirm: @escaping (URL) -> Void
    ) {
        let alert = UIAlertController(
            title: NSLocalizedString("Install from URL", tableName: "AppActions", comment: ""),
            message: NSLocalizedString("Enter the URL of the .ipa file to install.", tableName: "AppActions", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "https://example.com/app.ipa"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", tableName: "AppActions", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Continue", tableName: "AppActions", comment: ""), style: .default) { _ in
            guard let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(),
                  (scheme == "http" || scheme == "https") else {
                let errorAlert = UIAlertController(
                    title: NSLocalizedString("Invalid URL", tableName: "AppActions", comment: ""),
                    message: NSLocalizedString("Please enter a valid HTTP or HTTPS URL.", tableName: "AppActions", comment: ""),
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", tableName: "AppActions", comment: ""), style: .default))
                presentingVC.present(errorAlert, animated: true)
                return
            }
            
            self.present(ipaURL: url, from: presentingVC) {
                onConfirm(url)
            }
        })
        
        presentingVC.present(alert, animated: true)
    }
    
    public static func present(
        ipaURL: URL,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message: String
        if ipaURL.isFileURL {
            let appName = ipaURL.deletingPathExtension().lastPathComponent
            message = String(format: NSLocalizedString("Do you want to continue? This will install \"%@\".", tableName: "AppActions", comment: ""), appName)
        } else {
            message = String(format: NSLocalizedString("Do you want to continue? This will download and install from:\n%@", tableName: "AppActions", comment: ""), ipaURL.absoluteString)
        }
        
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
    
    public static func present(
        storeApp: StoreApp,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        guard SourceAppAccess.requireSource(storeApp, from: presentingViewController ?? UIApplication.shared.topViewController()) else {
            onCancel()
            return
        }
        let message = String(format: NSLocalizedString("Do you want to continue? This will install \"%@\".", tableName: "AppActions", comment: ""), storeApp.name)
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }

    public static func present(
        installedApp: InstalledApp,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message = String(format: NSLocalizedString("Do you want to continue? This will reinstall \"%@\".", tableName: "AppActions", comment: ""), installedApp.name)
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
    
    private static func presentConfirmation(
        message: String,
        from presentingViewController: UIViewController?,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard UserDefaults.standard.isInstallConfirmationEnabled else {
            onConfirm()
            return
        }
        
        let rootVC = presentingViewController ?? UIApplication.shared.topViewController()
        guard let presentingVC = rootVC else {
            onCancel()
            return
        }
        
        let alert = UIAlertController(
            title: NSLocalizedString("Install App", tableName: "AppActions", comment: ""),
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Install", tableName: "AppActions", comment: ""), style: .default) { _ in
            onConfirm()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", tableName: "AppActions", comment: ""), style: .cancel) { _ in
            onCancel()
        })
        
        presentingVC.present(alert, animated: true)
    }
}
