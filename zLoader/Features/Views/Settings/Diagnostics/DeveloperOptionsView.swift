//
//  DeveloperOptionsView.swift
//  ZLoader
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import CoreData
import MinimuxerCommon
import SideSign
import SwiftUI
import UniformTypeIdentifiers

#if !os(tvOS)
    import WidgetKit
#else
    import TVServices
#endif

extension Color {
    fileprivate static var settingsRowBackground: Color { Color(uiColor: .settingsCard) }
    fileprivate static var settingsDivider: Color { Color(uiColor: .separator) }
}

struct DeveloperOptionsView: View {
    @State private var responseCachingDisabled: Bool = UserDefaults.standard.responseCachingDisabled
    @State private var isVerboseOperationsLoggingEnabled: Bool = UserDefaults.standard.isVerboseOperationsLoggingEnabled
    @State private var isZLoaderVerboseLoggingEnabled: Bool = UserDefaults.standard.isZLoaderVerboseLoggingEnabled
    @State private var isAltWidgetVerboseLoggingEnabled: Bool = WidgetDataManager.shared.isVerboseLoggingEnabled
    @State private var isSideSignVerboseLoggingEnabled: Bool = UserDefaults.standard.isAltSignVerboseLoggingEnabled
    @State private var isMinimuxerVerboseLoggingEnabled: Bool = UserDefaults.standard.isMinimuxerVerboseLoggingEnabled
    @State private var isRotateLogsOnStartupEnabled: Bool = UserDefaults.standard.isRotateLogsOnStartupEnabled
    @State private var recreateDatabaseOnNextStart: Bool = UserDefaults.standard.recreateDatabaseOnNextStart
    @State private var acceptIPv6ConnectionConfig: Bool = UserDefaults.standard.acceptIPv6ConnectionConfig
    @State private var isAutoRetryRemotePairingPortEnabled: Bool = UserDefaults.standard
        .isAutoRetryRemotePairingPortEnabled
    @State private var tcpProbeTimeoutText: String = ""

    @State private var isExportingDB: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showClearRefreshAttemptsConfirmation: Bool = false
    @State private var showClearKeychainConfirmation: Bool = false
    @State private var showExportPasswordPrompt: Bool = false
    @State private var exportCertPassword: String = ""
    @State private var showOnboardingSheet: Bool = false
    @State private var exportedProfilesURL: URL?
    @State private var isDumpingProfiles: Bool = false
    @State private var showDumpProfilesAlert: Bool = false
    @State private var dumpProfilesAlertMessage: String = ""

    var body: some View {
        List {

            Section("Developer Features") {
                NavigationLink(destination: WirelessPairView()) {
                    SettingsEntryLabel(title: "Wireless Pairing", systemImage: "antenna.radiowaves.left.and.right")
                }
                NavigationLink(destination: WirelessIPAInstallerView()) {
                    SettingsEntryLabel(title: "Wireless IPA Installer", systemImage: "wifi")
                }
                NavigationLink(destination: CacheManagementView()) {
                    SettingsEntryLabel(title: "Refresh Cache", systemImage: "arrow.clockwise.circle")
                }
            }.zLoaderSettingsRows()

            // Section 1: Logging & Diagnostics
            Section {

                toggleRow(
                    title: "Disable URL Response Caching",
                    isOn: Binding(
                        get: { responseCachingDisabled },
                        set: { newValue in
                            responseCachingDisabled = newValue
                            UserDefaults.standard.responseCachingDisabled = newValue
                        }
                    ))

                toggleRow(
                    title: "Rotate Logs on Startup",
                    isOn: Binding(
                        get: { isRotateLogsOnStartupEnabled },
                        set: { newValue in
                            isRotateLogsOnStartupEnabled = newValue
                            UserDefaults.standard.isRotateLogsOnStartupEnabled = newValue
                            let suffixFormat: SuffixFormat = newValue ? .timestamp : .none
                            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                                appDelegate.consoleLog.updateConfiguration(
                                    baseName: "console", suffixFormat: suffixFormat, policy: .immediate)
                            }
                        }
                    ))

                toggleRow(
                    title: "zLoader Verbose Logging",
                    isOn: Binding(
                        get: { isZLoaderVerboseLoggingEnabled },
                        set: { newValue in
                            isZLoaderVerboseLoggingEnabled = newValue
                            UserDefaults.standard.isZLoaderVerboseLoggingEnabled = newValue
                            ZLoaderLogging.setLogging(newValue)
                        }
                    ))

                #if !os(tvOS)
                    let title = "Widget Verbose Logging"
                #else
                    let title = "Top Shelf Verbose Logging"
                #endif
                toggleRow(
                    title: title,
                    isOn: Binding(
                        get: { isAltWidgetVerboseLoggingEnabled },
                        set: { newValue in
                            isAltWidgetVerboseLoggingEnabled = newValue
                            WidgetDataManager.shared.isVerboseLoggingEnabled = newValue
                        }
                    ))

                toggleRow(
                    title: "SideSign Verbose Logging",
                    isOn: Binding(
                        get: { isSideSignVerboseLoggingEnabled },
                        set: { newValue in
                            isSideSignVerboseLoggingEnabled = newValue
                            UserDefaults.standard.isAltSignVerboseLoggingEnabled = newValue
                            SideSignLogging.setLogging(newValue)
                        }
                    ))

                toggleRow(
                    title: "Minimuxer Verbose Logging",
                    isOn: Binding(
                        get: { isMinimuxerVerboseLoggingEnabled },
                        set: { newValue in
                            isMinimuxerVerboseLoggingEnabled = newValue
                            UserDefaults.standard.isMinimuxerVerboseLoggingEnabled = newValue
                            minimuxerSetLogging(newValue)
                        }
                    ))

                toggleRow(
                    title: "Operations Verbose Logging",
                    isOn: Binding(
                        get: { isVerboseOperationsLoggingEnabled },
                        set: { newValue in
                            isVerboseOperationsLoggingEnabled = newValue
                            UserDefaults.standard.isVerboseOperationsLoggingEnabled = newValue
                        }
                    ))

                NavigationLink(destination: OperationsLoggingControlView()) {
                    HStack {
                        Text("Operations Logging Control")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.primary.opacity(0.4))
                    }
                    .frame(minHeight: 24)
                }

            } header: {
                Text("LOGGING & DIAGNOSTICS")

            }.zLoaderSettingsRows()

            // Section: Widget Options
            Section {

                SwiftUI.Button(action: { triggerReloadAllWidgets() }) {
                    HStack(spacing: 12) {

                        #if !os(tvOS)
                            let title = "Reload All Widgets"
                        #else
                            let title = "Reload Top Shelf"
                        #endif
                        SettingsEntryLabel(title: title)
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(minHeight: 24)
                }

                SwiftUI.Button(action: { triggerRotateWidgetLog() }) {
                    HStack(spacing: 12) {

                        #if !os(tvOS)
                            let title = "Rotate Widget Log"
                        #else
                            let title = "Rotate Top Shelf Log"
                        #endif
                        SettingsEntryLabel(title: title)
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(minHeight: 24)
                }

            } header: {
                #if !os(tvOS)
                    let title = "WIDGET OPTIONS"
                #else
                    let title = "TOP SHELF OPTIONS"
                #endif
                Text(LocalizedStringKey(title))
            }.zLoaderSettingsRows()

            // Section 2: Database Options
            Section {

                SwiftUI.Button(action: { exportDatabase() }) {
                    HStack(spacing: 12) {
                        Text("Export Database")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        if isExportingDB {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .frame(minHeight: 24)
                }
                .disabled(isExportingDB)

                SwiftUI.Button(action: { showClearRefreshAttemptsConfirmation = true }) {
                    HStack(spacing: 12) {
                        Text("Clear Refresh Attempts")
                            .font(.body)
                            .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.27))
                        Spacer()
                    }
                    .frame(minHeight: 24)
                }

                SwiftUI.Button(action: { showDeleteConfirmation = true }) {
                    HStack(spacing: 12) {
                        Text("Delete Database")
                            .font(.body)
                            .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.27))
                        Spacer()
                    }
                    .frame(minHeight: 24)
                }

                SwiftUI.Button(action: { showClearKeychainConfirmation = true }) {
                    HStack(spacing: 12) {
                        Text("Clear Keychain Items")
                            .font(.body)
                            .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.27))
                        Spacer()
                    }
                    .frame(minHeight: 24)
                }

                toggleRow(
                    title: "Wipe Database on Next Start",
                    isOn: Binding(
                        get: { recreateDatabaseOnNextStart },
                        set: { newValue in
                            recreateDatabaseOnNextStart = newValue
                            UserDefaults.standard.recreateDatabaseOnNextStart = newValue
                        }
                    ))

            } header: {
                Text("DATABASE OPTIONS")

            }.zLoaderSettingsRows()

            Section {

                SwiftUI.Button(action: { triggerStartBackgroundService() }) {
                    HStack(spacing: 12) {
                        Text("Start Background Service")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(minHeight: 24)
                }

                SwiftUI.Button(action: { triggerStopBackgroundService() }) {
                    HStack(spacing: 12) {
                        Text("Stop Background Service")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(minHeight: 24)
                }

            } header: {
                Text("BACKGROUND SERVICE")

            }.zLoaderSettingsRows()

            // Section: Device (TCP) Probe Timeout
            Section {

                HStack(spacing: 12) {
                    Text("Timeout (ms)")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()

                    TextField("ms", text: $tcpProbeTimeoutText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.primary)
                        .font(.system(size: 17))
                        .frame(width: 90)
                        .onValueChange(of: tcpProbeTimeoutText) { newValue in
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if filtered != newValue {
                                tcpProbeTimeoutText = filtered
                            }
                            if let timeout = Int(filtered), timeout > 0 {
                                minimuxerSetDeviceProbeTimeout(timeout)
                            }
                        }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 24)

                SwiftUI.Button(action: {
                    let defaultTimeout = AppConstants.Minimuxer.defaultTCPProbeTimeoutMs
                    tcpProbeTimeoutText = String(defaultTimeout)
                    minimuxerSetDeviceProbeTimeout(defaultTimeout)
                }) {
                    HStack(spacing: 12) {
                        Text("Use Default (\(AppConstants.Minimuxer.defaultTCPProbeTimeoutMs) ms)")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(minHeight: 24)
                }

            } header: {
                Text("DEVICE (TCP) PROBE TIMEOUT")

            }.zLoaderSettingsRows()

            // Section: Connection Config
            Section {

                toggleRow(
                    title: "Accept IPv6 Config",
                    isOn: Binding(
                        get: { acceptIPv6ConnectionConfig },
                        set: { newValue in
                            acceptIPv6ConnectionConfig = newValue
                            UserDefaults.standard.acceptIPv6ConnectionConfig = newValue
                        }
                    ))

                toggleRow(
                    title: "Auto Retry RemotePairing Port",
                    isOn: Binding(
                        get: { isAutoRetryRemotePairingPortEnabled },
                        set: { newValue in
                            isAutoRetryRemotePairingPortEnabled = newValue
                            UserDefaults.standard.isAutoRetryRemotePairingPortEnabled = newValue
                        }
                    ))

            } header: {
                Text("CONNECTION CONFIG")

            }.zLoaderSettingsRows()

            #if DEBUG
                // Section 3: Account Management
                Section {

                    SwiftUI.Button(action: { showImportAccountPicker() }) {
                        HStack(spacing: 12) {
                            Text("Import Account JSON")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .frame(minHeight: 24)
                    }

                    SwiftUI.Button(action: {
                        if AuthManager.shared.currentAppleID == nil || AuthManager.shared.password == nil
                            || CertificateManager.shared.activeCertificate == nil
                        {
                            if let top = UIApplication.shared.topViewController() {
                                let toastView = ToastView(
                                    text: NSLocalizedString("Failed to export account!", comment: ""),
                                    detailText: "Account not found or missing credentials.")
                                toastView.show(in: top)
                            }
                        } else {
                            exportCertPassword = ""
                            showExportPasswordPrompt = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Export Account JSON")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .frame(minHeight: 24)
                    }

                } header: {
                    Text("ACCOUNT MANAGEMENT")

                }.zLoaderSettingsRows()
            #endif

            Section {

                SwiftUI.Button(action: {
                    Task {
                        await dumpProvisioningProfiles()
                    }
                }) {
                    HStack(spacing: 12) {
                        Text("Dump Provisioning Profiles")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        if isDumpingProfiles {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .frame(minHeight: 24)
                }
                .disabled(isDumpingProfiles)

            } header: {
                Text("PROVISIONING PROFILES")

            }.zLoaderSettingsRows()

            Section {

                SwiftUI.Button(action: { showOnboardingSheet = true }) {
                    HStack(spacing: 12) {
                        Text("Replay Onboarding")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.primary.opacity(0.4))
                    }
                    .frame(minHeight: 24)
                }
                .sheet(isPresented: $showOnboardingSheet) {
                    OnboardingView(onFinish: {
                        showOnboardingSheet = false
                    })
                }

                SwiftUI.Button(action: {
                    UserDefaults.standard.hasCompletedOnboarding = false
                    UserDefaults.standard.set(0, forKey: "zLoader.onboarding.currentStep")
                    UserDefaults.standard.set(false, forKey: "zLoader.onboarding.eligibleForTunnel")
                    UserDefaults.standard.synchronize()
                    if let top = UIApplication.shared.topViewController() {
                        let toastView = ToastView(
                            text: NSLocalizedString("Onboarding reset for next launch", comment: ""), detailText: nil)
                        toastView.show(in: top)
                    }
                }) {
                    HStack(spacing: 12) {
                        Text("Reset Onboarding State")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(minHeight: 24)
                }

            } header: {
                Text("ONBOARDING")

            }.zLoaderSettingsRows()

        }
        .background(Color(uiColor: .settingsBackground))
        .navigationTitle("Developer Options")
        .zLoaderSettingsPage()
        .labelStyle(.titleAndIcon)
        #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
        .alert("Delete Database", isPresented: $showDeleteConfirmation) {
            SwiftUI.Button("Delete & Exit", role: .destructive) {
                _ = DatabaseManager.deleteDatabase()
                exit(0)
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting the database will remove all app entries and sources from zLoader.")
        }
        .alert("Clear Refresh Attempts", isPresented: $showClearRefreshAttemptsConfirmation) {
            SwiftUI.Button("Clear", role: .destructive) {
                clearRefreshAttempts()
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear all existing refresh attempt entries?")
        }
        #if DEBUG
            .alert("Export Account", isPresented: $showExportPasswordPrompt) {
                SecureField("Certificate Password", text: $exportCertPassword)
                SwiftUI.Button("Export") {
                    exportAccountJSON(password: exportCertPassword)
                }
                SwiftUI.Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enter a password for the certificate.")
            }
        #endif
        .alert("Clear Keychain Items", isPresented: $showClearKeychainConfirmation) {
            SwiftUI.Button("Clear All", role: .destructive) {
                Keychain.shared.clearAll()
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to clear all keychain items related to this zLoader instance?")
        }
        .sheet(isPresented: Binding(get: { exportedProfilesURL != nil }, set: { if !$0 { exportedProfilesURL = nil } }))
        {
            if let url = exportedProfilesURL { ActivityViewController(activityItems: [url]) }
        }
        .alert("Dump Profiles", isPresented: $showDumpProfilesAlert) {
            SwiftUI.Button("OK", role: .cancel) {}
        } message: {
            Text(dumpProfilesAlertMessage)
        }
        .onAppear {
            tcpProbeTimeoutText = String(minimuxerGetDeviceProbeTimeout())
        }
    }

    private func dumpProvisioningProfiles() async {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        isDumpingProfiles = true
        defer { isDumpingProfiles = false }
        do {
            let zipPath = try await safeDumpProfiles(docsURL.path)
            let url = URL(fileURLWithPath: zipPath)
            guard !zipPath.isEmpty, FileManager.default.fileExists(atPath: url.path),
                (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0
            else {
                throw OperationError.invalidParameters(
                    NSLocalizedString("No provisioning profile archive was created.", comment: ""))
            }
            exportedProfilesURL = url
        } catch {
            dumpProfilesAlertMessage = error.localizedDescription
            showDumpProfilesAlert = true
        }
    }

    #if DEBUG
        private func showImportAccountPicker() {
            guard let top = UIApplication.shared.topViewController() else { return }
            #if !os(tvOS)
                let picker = UIDocumentPickerViewController(
                    forOpeningContentTypes: [UTType(filenameExtension: "sideconf")!, .json], asCopy: false)
                ImportExport.documentPickerHandler = DocumentPickerHandler { selectedURL in
                    guard let url = selectedURL else { return }
                    Task { @MainActor in
                        do {
                            try await ImportExport.importAccountJSON(from: url)
                            let email = AuthManager.shared.currentAppleID ?? ""
                            let toastView = ToastView(
                                text: String(
                                    format: NSLocalizedString("Successfully imported '%@'!", comment: ""), email),
                                detailText: "zLoader should be fully operational!")
                            toastView.show(in: top)
                        } catch {
                            let toastView = ToastView(
                                text: NSLocalizedString("Failed to import account JSON!", comment: ""),
                                detailText: error.localizedDescription)
                            toastView.show(in: top)
                        }
                    }
                }
                picker.delegate = ImportExport.documentPickerHandler
                top.present(picker, animated: true)
            #else
                TVWebFileTransferManager.shared.startImport(
                    acceptedExtensions: ["sideconf", "json"],
                    title: "Import Account",
                    presentingVC: top
                ) { selectedURL in
                    guard let url = selectedURL else { return }
                    Task { @MainActor in
                        do {
                            try await ImportExport.importAccountJSON(from: url)
                            let email = AuthManager.shared.currentAppleID ?? ""
                            let toastView = ToastView(
                                text: String(
                                    format: NSLocalizedString("Successfully imported '%@'!", comment: ""), email),
                                detailText: "zLoader should be fully operational!")
                            toastView.show(in: top)
                        } catch {
                            let toastView = ToastView(
                                text: NSLocalizedString("Failed to import account JSON!", comment: ""),
                                detailText: error.localizedDescription)
                            toastView.show(in: top)
                        }
                    }
                }
            #endif
        }

        private func exportAccountJSON(password: String) {
            guard let top = UIApplication.shared.topViewController() else { return }
            guard let account = ImportExport.exportAccountJSON(password: password) else {
                let toastView = ToastView(
                    text: NSLocalizedString("Failed to export account!", comment: ""),
                    detailText: "Account not found or missing credentials.")
                toastView.show(in: top)
                return
            }

            guard let accountData = try? Foundation.JSONEncoder().encode(account) else {
                let toastView = ToastView(
                    text: NSLocalizedString("Failed to export account data!", comment: ""),
                    detailText: "Account malformed.")
                toastView.show(in: top)
                return
            }

            let tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent("\(account.email).sideconf")
            do {
                try accountData.write(to: tmpPath)
                #if !os(tvOS)
                    let exportVC = UIDocumentPickerViewController(forExporting: [tmpPath], asCopy: false)
                    top.present(exportVC, animated: true)
                #else
                    TVWebFileTransferManager.shared.startExport(
                        fileURL: tmpPath, title: "Export Account", presentingVC: top)
                #endif
            } catch {
                let toastView = ToastView(
                    text: NSLocalizedString("Failed to export account!", comment: ""),
                    detailText: error.localizedDescription)
                toastView.show(in: top)
            }
        }
    #endif

    private func clearRefreshAttempts() {
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        context.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = RefreshAttempt.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            _ = try? context.execute(deleteRequest)
            try? context.save()
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { SettingsEntryLabel(title: title) }
            .tint(Color(uiColor: .altPrimary))
    }

    private func exportDatabase() {
        guard !isExportingDB else { return }
        isExportingDB = true

        Task {
            do {
                let exportedURL = try await CoreDataHelper.exportCoreDataStore()
                debugLog("[DeveloperOptionsView] ExportedURL: \(exportedURL)")
                await MainActor.run {
                    isExportingDB = false
                }
            } catch {
                debugLog("[DeveloperOptionsView] Export error: \(error)")
                await MainActor.run {
                    isExportingDB = false
                }
            }
        }
    }

    private func triggerStartBackgroundService() {
        guard let top = UIApplication.shared.topViewController() else { return }
        let started = BackgroundServiceManager.ensureBackgroundServicesStarted()
        let modeName = UserDefaults.standard.backgroundServiceMode.displayName
        if started {
            let toastView = ToastView(
                text: NSLocalizedString("Started Background Service", comment: ""),
                detailText: "\(modeName) keepalive is running.")
            toastView.show(in: top)
        } else {
            let toastView = ToastView(
                text: NSLocalizedString("Background Service Disabled", comment: ""),
                detailText: "Enable background service in User Customizations.")
            toastView.show(in: top)
        }
    }

    private func triggerStopBackgroundService() {
        guard let top = UIApplication.shared.topViewController() else { return }
        BackgroundServiceManager.stop()
        let toastView = ToastView(
            text: NSLocalizedString("Stopped Background Service", comment: ""),
            detailText: "Background keepalive service stopped.")
        toastView.show(in: top)
    }

    private func triggerReloadAllWidgets() {
        #if !os(tvOS)
            WidgetCenter.shared.reloadAllTimelines()
            let title = NSLocalizedString("Reloaded All Widgets", comment: "")
            let detail = "Triggered timeline refresh for all widgets."
        #else
            NotificationCenter.default.post(name: .TVTopShelfItemsDidChange, object: nil)
            let title = NSLocalizedString("Reloaded Top Shelf", comment: "")
            let detail = "Triggered Top Shelf refresh."
        #endif
        if let top = UIApplication.shared.topViewController() {
            let toastView = ToastView(text: title, detailText: detail)
            toastView.show(in: top)
        }
    }

    private func triggerRotateWidgetLog() {
        guard let top = UIApplication.shared.topViewController() else { return }
        #if !os(tvOS)
            let logName = "Widget"
        #else
            let logName = "Top Shelf"
        #endif
        do {
            if let rotatedURL = try WidgetLogManager.rotateLog() {
                let toastView = ToastView(
                    text: String(format: NSLocalizedString("Rotated %@ Log", comment: ""), logName),
                    detailText: "Saved to WidgetLogs/\(rotatedURL.lastPathComponent)")
                toastView.show(in: top)
            } else {
                let toastView = ToastView(
                    text: String(format: NSLocalizedString("%@ Log Empty", comment: ""), logName),
                    detailText: "Nothing to rotate.")
                toastView.show(in: top)
            }
        } catch {
            let toastView = ToastView(
                text: NSLocalizedString("Failed to Rotate Log", comment: ""), detailText: error.localizedDescription)
            toastView.show(in: top)
        }
    }
}
