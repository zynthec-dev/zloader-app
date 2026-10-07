//
//  UserCustomizationsView.swift
//  ZLoader
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Minimuxer
import SwiftUI

extension Color {
    fileprivate static var settingsRowBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    fileprivate static var settingsDivider: Color { Color(uiColor: .separator) }
}

struct UserCustomizationsView: View {
    @State private var selectedBackend: GatewayBackend = selectedGatewayBackendCache
    @State private var isBackgroundServiceEnabled: Bool = UserDefaults.standard.isBackgroundServiceEnabled
    @State private var selectedBackgroundServiceMode: BackgroundServiceMode = UserDefaults.standard
        .backgroundServiceMode
    @State private var useOnDeviceAnisette: Bool = UserDefaults.standard.useOnDeviceAnisette
    @State private var showAnisetteRestartConfirmation: Bool = false
    @State private var customizeInfoPlist: Bool = UserDefaults.standard.customizeInfoPlist
    @State private var preferSheetForInfoPlistCustomization: Bool = UserDefaults.standard
        .preferSheetForInfoPlistCustomization
    @State private var customizeEntitlements: Bool = UserDefaults.standard.customizeEntitlements
    @State private var preferSheetForEntitlementsCustomization: Bool = UserDefaults.standard
        .preferSheetForEntitlementsCustomization
    @State private var customizeAppId: Bool = UserDefaults.standard.customizeAppId
    @State private var customizeAppIcon: Bool = UserDefaults.standard.customizeAppIcon
    @State private var customizeProvisioningProfile: Bool = UserDefaults.standard.customizeProvisioningProfile
    @State private var customizeAppExtensions: AppExtensionCustomization = UserDefaults.standard.customizeAppExtensions
    @State private var appImportSourceMode: AppImportSourceMode = UserDefaults.standard.appImportSourceMode
    @State private var isInstallConfirmationEnabled: Bool = UserDefaults.standard.isInstallConfirmationEnabled
    @State private var isClearCustomizationsOnUninstallEnabled: Bool = UserDefaults.standard
        .isClearCustomizationsOnUninstallEnabled
    @State private var isAutoLaunchAppAfterInstallEnabled: Bool = UserDefaults.standard
        .isAutoLaunchAppAfterInstallEnabled
    @State private var autoFixAppGroupIDs: Bool = UserDefaults.standard.autoFixAppGroupIDs
    @State private var preferResignedIPA: Bool = UserDefaults.standard.preferResignedIPA
    @State private var pendingPreferIPAOngoing: Bool = false
    @State private var showPreferIPAToggleAlert: Bool = false
    @State private var pendingBackendOption: GatewayBackend? = nil
    @State private var showBackendRestartConfirmation: Bool = false
    @State private var skipNonCopyableFiles: Bool = UserDefaults.standard.skipNonCopyableBackupFiles
    @State private var appVerificationDisabled: Bool = UserDefaults.standard.appVerificationDisabled
    @State private var isBundleIDVerificationEnabled: Bool = UserDefaults.standard.isBundleIDVerificationEnabled
    @State private var isiOSVersionVerificationEnabled: Bool = UserDefaults.standard.isiOSVersionVerificationEnabled
    @State private var isAppVersionVerificationEnabled: Bool = UserDefaults.standard.isAppVersionVerificationEnabled
    @State private var isChecksumVerificationEnabled: Bool = UserDefaults.standard.isChecksumVerificationEnabled
    @State private var isFileSizeVerificationEnabled: Bool = UserDefaults.standard.isFileSizeVerificationEnabled
    @State private var permissionCheckingDisabled: Bool = UserDefaults.standard.permissionCheckingDisabled
    @State private var isCellularRefreshEnabled: Bool = UserDefaults.standard.isCellularRefreshEnabled

    @State private var isFreeAccount: Bool = false

    struct EditDialogState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let placeholder: String
        let keyboardType: UIKeyboardType
        let onSave: (String) -> Void
    }

    @State private var editDialog: EditDialogState? = nil
    @State private var editingValueText: String = ""

    var body: some View {
        Form {
            // Section 0: APPEARANCE & THEMES
            Section("Appearance") {

                NavigationLink(destination: ThemePickerView()) {
                    HStack {
                        SettingsEntryLabel(title: "Appearance", systemImage: "paintpalette")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(uiColor: ThemeManager.shared.primaryColor))
                                .frame(width: 14, height: 14)
                        }
                    }

                    .padding(.vertical, 14)
                }

            }.listRowBackground(ZLoaderGlassBackground())

            // Section 1: ANISETTE
            Section("Anisette") {

                toggleRow(
                    title: "On-Device Anisette",
                    subtitle: "Run ADI emulation directly on device instead of remote servers",
                    isOn: Binding(
                        get: { useOnDeviceAnisette },
                        set: { newValue in
                            useOnDeviceAnisette = newValue
                            showAnisetteRestartConfirmation = true
                        }
                    )
                )

                NavigationLink(destination: AnisetteDataView()) {
                    HStack {
                        SettingsEntryLabel(title: "Anisette Client Configuration")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }

                    .frame(minHeight: 32)
                }

                SwiftUI.Button(role: .destructive) {
                    presentResetAdiDialog()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            SettingsEntryLabel(title: "Reset adi.pb")
                                .font(.body)
                                .foregroundColor(.red)
                            Text("Clear local Anisette provisioning data from Keychain")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color.secondary)
                        }
                        Spacer()
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                    }

                    .padding(.vertical, 10)
                    .frame(minHeight: 50)
                }

            }.listRowBackground(ZLoaderGlassBackground())

            // Section: SIDESIGN
            Section("SideSign") {

                NavigationLink(destination: SideSignConfigurationView()) {
                    HStack {
                        SettingsEntryLabel(title: "SideSign Client Configuration")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }

                    .frame(minHeight: 32)
                }

            }.listRowBackground(ZLoaderGlassBackground())

            // Section 2: GENERAL
            generalSection

            // Section 2: APP VERIFICATION
            Section("App Verification") {

                toggleRow(
                    title: "Disable All Verifications",
                    isOn: Binding(
                        get: { appVerificationDisabled },
                        set: { newValue in
                            appVerificationDisabled = newValue
                            UserDefaults.standard.appVerificationDisabled = newValue
                        }
                    ))

                Group {
                    toggleRow(
                        title: "Bundle Identifier Check",
                        isOn: Binding(
                            get: { isBundleIDVerificationEnabled },
                            set: { newValue in
                                isBundleIDVerificationEnabled = newValue
                                UserDefaults.standard.isBundleIDVerificationEnabled = newValue
                            }
                        ))

                    toggleRow(
                        title: "iOS Version Check",
                        isOn: Binding(
                            get: { isiOSVersionVerificationEnabled },
                            set: { newValue in
                                isiOSVersionVerificationEnabled = newValue
                                UserDefaults.standard.isiOSVersionVerificationEnabled = newValue
                            }
                        ))

                    toggleRow(
                        title: "App Version Check",
                        isOn: Binding(
                            get: { isAppVersionVerificationEnabled },
                            set: { newValue in
                                isAppVersionVerificationEnabled = newValue
                                UserDefaults.standard.isAppVersionVerificationEnabled = newValue
                            }
                        ))

                    toggleRow(
                        title: "Checksum (SHA-256) Check",
                        isOn: Binding(
                            get: { isChecksumVerificationEnabled },
                            set: { newValue in
                                isChecksumVerificationEnabled = newValue
                                UserDefaults.standard.isChecksumVerificationEnabled = newValue
                            }
                        ))

                    toggleRow(
                        title: "App File Size Check",
                        isOn: Binding(
                            get: { isFileSizeVerificationEnabled },
                            set: { newValue in
                                isFileSizeVerificationEnabled = newValue
                                UserDefaults.standard.isFileSizeVerificationEnabled = newValue
                            }
                        ))

                    toggleRow(
                        title: "Permission Checks",
                        isOn: Binding(
                            get: { !permissionCheckingDisabled },
                            set: { newValue in
                                permissionCheckingDisabled = !newValue
                                UserDefaults.standard.permissionCheckingDisabled = !newValue
                            }
                        ))
                }
                .disabled(appVerificationDisabled)
                .opacity(appVerificationDisabled ? 0.5 : 1.0)

            }.listRowBackground(ZLoaderGlassBackground())

            // Section 4: CELLULAR REFRESH
            cellularRefreshShortcutsSection

            // Section 5: MINIMUXER BACKEND
            Section("Minimuxer Backend") {

                ForEach(GatewayBackend.allCases, id: \.self) { backend in
                    SwiftUI.Button(action: {
                        if selectedBackend != backend {
                            if UserDefaults.standard.isMinimuxerBackendHotswapEnabled {
                                applyBackendChange(backend, restartRequired: false)
                            } else {
                                pendingBackendOption = backend
                                showBackendRestartConfirmation = true
                            }
                        }
                    }) {
                        HStack {
                            Text(backend.rawValue)
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedBackend == backend {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(uiColor: ThemeManager.shared.primaryColor))
                            }
                        }

                        .padding(.vertical, 14)
                    }
                    if backend != GatewayBackend.allCases.last {

                    }
                }

            }.listRowBackground(ZLoaderGlassBackground())

            // Section 6: BACKGROUND SERVICE
            Section("Background Service") {

                toggleRow(
                    title: "Enable Background Keepalive",
                    isOn: Binding(
                        get: { isBackgroundServiceEnabled },
                        set: { newValue in
                            isBackgroundServiceEnabled = newValue
                            BackgroundServiceManager.setEnabled(newValue)
                        }
                    ))

                ForEach(BackgroundServiceMode.allCases, id: \.self) { mode in
                    SwiftUI.Button(action: {
                        selectedBackgroundServiceMode = mode
                        BackgroundServiceManager.switchTo(mode: mode)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(mode.displayName)
                                    .font(.body)
                                    .foregroundColor(isBackgroundServiceEnabled ? .primary : Color.primary.opacity(0.4))
                                Text(mode.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.primary.opacity(isBackgroundServiceEnabled ? 0.6 : 0.3))
                            }
                            Spacer()
                            if selectedBackgroundServiceMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(
                                        isBackgroundServiceEnabled
                                            ? Color(uiColor: ThemeManager.shared.primaryColor)
                                            : Color.primary.opacity(0.3))
                            }
                        }

                        .padding(.vertical, 12)
                    }
                    .disabled(!isBackgroundServiceEnabled)
                }

            }.listRowBackground(ZLoaderGlassBackground())

        }
        .background(ZLoaderAppBackground())
        .navigationTitle("User Customizations")
        .labelStyle(.titleOnly)
        #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
        .alert("Restart Required", isPresented: $showAnisetteRestartConfirmation) {
            SwiftUI.Button("Restart Now", role: .destructive) {
                Task {
                    await AuthManager.shared.signOut(keepCertificate: true, keepAnisetteData: false)
                    UserDefaults.standard.useOnDeviceAnisette = useOnDeviceAnisette
                    exit(0)
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {
                useOnDeviceAnisette = UserDefaults.standard.useOnDeviceAnisette
            }
        } message: {
            Text(
                "Changing Anisette config will invalidate your current provisioned Anisette data and you will be signed out.\n\nThis action will require a restart, do you want to proceed?"
            )
        }
        .alert("Restart Required", isPresented: $showBackendRestartConfirmation) {
            SwiftUI.Button("Restart Now", role: .destructive) {
                if let newBackend = pendingBackendOption {
                    applyBackendChange(newBackend, restartRequired: true)
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {
                pendingBackendOption = nil
            }
        } message: {
            Text("Changing the Minimuxer backend requires restarting zLoader. If canceled, changes will not be saved.")
        }
        .alert(
            pendingPreferIPAOngoing ? "Prefer Resigned IPA" : "Prefer App Bundle",
            isPresented: $showPreferIPAToggleAlert
        ) {
            SwiftUI.Button("Switch") {
                preferResignedIPA = pendingPreferIPAOngoing
                UserDefaults.standard.preferResignedIPA = pendingPreferIPAOngoing
            }
            SwiftUI.Button("Cancel", role: .cancel) {
                pendingPreferIPAOngoing = preferResignedIPA
            }
        } message: {
            if pendingPreferIPAOngoing {
                Text(
                    "Switching to Resigned IPA prioritizes install speed (~40% faster) by packaging an uncompressed IPA for fast transfer, but temporarily uses additional disk space during packaging."
                )
            } else {
                Text(
                    "Switching to App Bundle prioritizes storage efficiency by transferring the app bundle directly without packaging a temporary IPA, but transfer speeds will be noticeably slower."
                )
            }
        }

        .alert(
            editDialog?.title ?? "",
            isPresented: Binding<Bool>(
                get: { editDialog != nil },
                set: { if !$0 { editDialog = nil } }
            )
        ) {
            TextField(editDialog?.placeholder ?? "", text: $editingValueText)
                #if !os(tvOS)
                    .keyboardType(editDialog?.keyboardType ?? .default)
                #endif
            SwiftUI.Button("OK") {
                if let dialog = editDialog {
                    dialog.onSave(editingValueText)
                }
                editDialog = nil
            }
            SwiftUI.Button("Cancel", role: .cancel) {
                editDialog = nil
            }
        } message: {
            Text(editDialog?.message ?? "")
        }
        .task {
            isFreeAccount = (try? await AuthManager.shared.getAuthenticatedTeam())?.type == .free
        }
    }

    private func toggleRow(title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                SettingsEntryLabel(title: title)
                if let subtitle {
                    Text(LocalizedStringKey(subtitle)).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .tint(Color(uiColor: .altPrimary))
    }

    private func textFieldRow(
        title: String,
        subtitle: String? = nil,
        placeholder: String,
        value: String,
        unit: String? = nil,
        onTap: @escaping () -> Void
    ) -> some View {
        SwiftUI.Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    SettingsEntryLabel(title: title)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle = subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Text(value.isEmpty ? placeholder : (unit != nil ? "\(value) \(unit!)" : value))
                        .font(.system(size: 15))
                        .foregroundColor(value.isEmpty ? Color.primary.opacity(0.3) : .primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(8)
            }

            .padding(.vertical, 10)
        }
    }

    private var cellularRefreshShortcutsSection: some View {
        Section("Cellular Refresh") {
            toggleRow(
                title: "Cellular Refresh",
                subtitle: "Use cellular Internet while the embedded local tunnel handles device operations",
                isOn: Binding(
                    get: { isCellularRefreshEnabled },
                    set: {
                        isCellularRefreshEnabled = $0
                        CellularRefreshManager.shared.setEnabled($0)
                    }
                ))
            Text(
                "No cellular toggle shortcuts are needed. Requires correctly provisioned Network Extension entitlements. Cellular-only device connectivity is experimental and must be verified on your iPhone."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

        }.listRowBackground(ZLoaderGlassBackground())
    }

    private var customizeAppExtensionsBinding: Binding<AppExtensionCustomization> {
        Binding<AppExtensionCustomization>(
            get: { customizeAppExtensions },
            set: { newValue in
                customizeAppExtensions = newValue
                UserDefaults.standard.customizeAppExtensions = newValue
            }
        )
    }

    private var appImportSourceModeBinding: Binding<AppImportSourceMode> {
        Binding<AppImportSourceMode>(
            get: { appImportSourceMode },
            set: { newValue in
                appImportSourceMode = newValue
                UserDefaults.standard.appImportSourceMode = newValue
            }
        )
    }

    @ViewBuilder
    private var generalSection: some View {
        Section("General") {

            toggleRow(
                title: "Customize Info.plist",
                isOn: Binding(
                    get: { customizeInfoPlist },
                    set: { newValue in
                        customizeInfoPlist = newValue
                        UserDefaults.standard.customizeInfoPlist = newValue
                    }
                ))

            toggleRow(
                title: "Customize AppID",
                isOn: Binding(
                    get: { customizeInfoPlist ? true : customizeAppId },
                    set: { newValue in
                        customizeAppId = newValue
                        UserDefaults.standard.customizeAppId = newValue
                    }
                )
            )
            .disabled(customizeInfoPlist)
            .opacity(customizeInfoPlist ? 0.4 : 1.0)

            HStack {
                SettingsEntryLabel(title: "Customize Extensions")
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Picker("", selection: customizeAppExtensionsBinding) {
                    ForEach(AppExtensionCustomization.allCases) { (option: AppExtensionCustomization) in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.primary.opacity(0.7))
            }

            .padding(.vertical, 10)
            .frame(minHeight: 50)

            HStack {
                SettingsEntryLabel(title: "Default Import Mode")
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Picker("", selection: appImportSourceModeBinding) {
                    ForEach(AppImportSourceMode.allCases) { (option: AppImportSourceMode) in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.primary.opacity(0.7))
            }

            .padding(.vertical, 10)
            .frame(minHeight: 50)

            toggleRow(
                title: "Confirm App Installation",
                subtitle: "Prompt for confirmation before installing or importing an app",
                isOn: Binding(
                    get: { isInstallConfirmationEnabled },
                    set: { newValue in
                        isInstallConfirmationEnabled = newValue
                        UserDefaults.standard.isInstallConfirmationEnabled = newValue
                    }
                )
            )

            toggleRow(
                title: "Clear Customizations on Uninstall",
                subtitle: "Reset assigned profiles, custom certificates, and metadata when an app is deleted",
                isOn: Binding(
                    get: { isClearCustomizationsOnUninstallEnabled },
                    set: { newValue in
                        isClearCustomizationsOnUninstallEnabled = newValue
                        UserDefaults.standard.isClearCustomizationsOnUninstallEnabled = newValue
                    }
                )
            )

            toggleRow(
                title: "Auto-Launch App After Install",
                subtitle: "Automatically open apps after installation completes",
                isOn: Binding(
                    get: { isAutoLaunchAppAfterInstallEnabled },
                    set: { newValue in
                        isAutoLaunchAppAfterInstallEnabled = newValue
                        UserDefaults.standard.isAutoLaunchAppAfterInstallEnabled = newValue
                    }
                )
            )

            toggleRow(
                title: "Customize Entitlements",
                isOn: Binding(
                    get: { customizeEntitlements },
                    set: { newValue in
                        customizeEntitlements = newValue
                        UserDefaults.standard.customizeEntitlements = newValue
                    }
                ))

            toggleRow(
                title: "Auto-Fix AppGroup IDs",
                subtitle: isFreeAccount
                    ? "Required for free developer accounts" : "Automatically fix App Group casing mismatches",
                isOn: Binding(
                    get: { isFreeAccount ? true : autoFixAppGroupIDs },
                    set: { newValue in
                        guard !isFreeAccount else { return }
                        autoFixAppGroupIDs = newValue
                        UserDefaults.standard.autoFixAppGroupIDs = newValue
                    }
                )
            )
            .disabled(isFreeAccount)

            toggleRow(
                title: "Customize App Icon",
                subtitle: "Prompt to choose a custom icon before installing",
                isOn: Binding(
                    get: { customizeAppIcon },
                    set: { newValue in
                        customizeAppIcon = newValue
                        UserDefaults.standard.customizeAppIcon = newValue
                    }
                )
            )

            toggleRow(
                title: "Customize Provisioning Profile",
                subtitle: "Prompt to select a provisioning profile before installing",
                isOn: Binding(
                    get: { customizeProvisioningProfile },
                    set: { newValue in
                        customizeProvisioningProfile = newValue
                        UserDefaults.standard.customizeProvisioningProfile = newValue
                    }
                )
            )

            toggleRow(
                title: "Prefer Resigned IPA",
                subtitle: "Prefer IPA (speed) vs App (storage) efficiency",
                isOn: Binding(
                    get: { preferResignedIPA },
                    set: { newValue in
                        pendingPreferIPAOngoing = newValue
                        showPreferIPAToggleAlert = true
                    }
                )
            )

            toggleRow(
                title: "Skip Uncopyable Backup Files",
                isOn: Binding(
                    get: { skipNonCopyableFiles },
                    set: { newValue in
                        skipNonCopyableFiles = newValue
                        UserDefaults.standard.skipNonCopyableBackupFiles = newValue
                    }
                ))

            toggleRow(
                title: "Prefer Sheet for Info.plist",
                subtitle: "Use sheet instead of dialog",
                isOn: Binding(
                    get: { preferSheetForInfoPlistCustomization },
                    set: { newValue in
                        preferSheetForInfoPlistCustomization = newValue
                        UserDefaults.standard.preferSheetForInfoPlistCustomization = newValue
                    }
                )
            )
            .disabled(!customizeInfoPlist)
            .opacity(!customizeInfoPlist ? 0.4 : 1.0)

            toggleRow(
                title: "Prefer Sheet for Entitlements",
                subtitle: "Use sheet instead of dialog",
                isOn: Binding(
                    get: { preferSheetForEntitlementsCustomization },
                    set: { newValue in
                        preferSheetForEntitlementsCustomization = newValue
                        UserDefaults.standard.preferSheetForEntitlementsCustomization = newValue
                    }
                )
            )
            .disabled(!customizeEntitlements)
            .opacity(!customizeEntitlements ? 0.4 : 1.0)

        }.listRowBackground(ZLoaderGlassBackground())
    }

    private func presentResetAdiDialog() {
        guard let top = UIApplication.shared.topViewController() else { return }
        let alertController = UIAlertController(
            title: NSLocalizedString("Reset adi.pb", comment: ""),
            message: NSLocalizedString(
                "This will sign you out of Apple ID in zLoader and clear the provisioned adi.pb data from your Keychain. Your active signing certificate will be preserved.",
                comment: ""),
            preferredStyle: .alert
        )
        let contentVC = ResetAdiAlertViewController()
        alertController.setValue(contentVC, forKey: "contentViewController")

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        let resetAction = UIAlertAction(title: NSLocalizedString("Reset & Sign Out", comment: ""), style: .destructive)
        { _ in
            let keepHeaders = contentVC.isKeepHeadersChecked
            Task {
                await AuthManager.shared.signOut(
                    keepCertificate: true, keepAnisetteData: false, keepAnisetteHeaders: keepHeaders)
                debugLog("Reset adi.pb (keepAnisetteHeaders: \(keepHeaders)) and signed out")
                if let topVC = UIApplication.shared.topViewController() {
                    let detail =
                        keepHeaders
                        ? NSLocalizedString(
                            "Signed out of Apple ID. You can now sign back in with fresh provisioning.", comment: "")
                        : NSLocalizedString(
                            "Signed out of Apple ID. Reset adi.pb and header configs to defaults.", comment: "")
                    ToastView(
                        text: NSLocalizedString("Cleared adi.pb!", comment: ""),
                        detailText: detail
                    ).show(in: topVC)
                }
            }
        }

        alertController.addAction(cancelAction)
        alertController.addAction(resetAction)
        top.present(alertController, animated: true, completion: nil)
    }

    private func applyBackendChange(_ newBackend: GatewayBackend, restartRequired: Bool) {
        selectedBackend = newBackend
        selectedGatewayBackendCache = newBackend
        UserDefaults.standard.minimuxerGatewayBackend = newBackend.rawValue
        UserDefaults.standard.synchronize()
        if restartRequired {
            exit(0)
        } else {
            syncMinimuxerBackendFromUserDefaults()
        }
    }
}
