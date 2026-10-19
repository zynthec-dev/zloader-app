//
//  OperationsLoggingControlView.swift
//  ZLoader
//
//  Created by Magesh K on 14/01/25.
//  Copyright © 2025 SideStore. All rights reserved.
//

import SwiftUI

extension Color {
    fileprivate static var settingsRowBackground: Color { Color(uiColor: .settingsCard) }
    fileprivate static var settingsDivider: Color { Color(uiColor: .separator) }
}

private let pipelineStepToggles: [(name: String, step: PipelineStep)] = [
    ("Backup App Data", .backupAppData),
    ("Cache App", .cacheApp),
    ("Change App Icon", .changeAppIcon),
    ("Clean Staged App", .cleanStagedApp),
    ("Deactivate App", .deactivateApp),
    ("Download App", .downloadApp),
    ("Fetch Provisioning Profiles", .fetchProvisioningProfiles),
    ("Install App", .installApp),
    ("Preflight Checks", .preflightChecks),
    ("Prepare App Extension Bundle IDs", .prepareAppExtensionBundleIDs),
    ("Refresh App", .refreshApp),
    ("Remove App", .removeApp),
    ("Remove App Extensions", .removeAppExtensions),
    ("Remove Backup Data", .removeBackupData),
    ("Resign App", .resignApp),
    ("Restore App Data", .restoreAppData),
    ("Send App", .sendApp),
    ("Stage App", .stageApp),
    ("Stage Backup App", .stageBackupApp),
    ("Update App Certificate", .updateAppCertificate),
    ("User Customization", .userCustomization),
    ("Verify App", .verifyApp),
    ("Verify Certificate", .verifyCertificate),
    ("Create IPA", .createIPA),
]

private let standaloneStepToggles: [(name: String, step: StandaloneStep)] = [
    ("Sign In", .signIn),
    ("Background Refresh Apps", .backgroundRefreshApps),
    ("Clear App Cache", .clearAppCache),
    ("Enable JIT", .enableJIT),
    ("Sync App IDs", .syncAppIDs),
    ("Fetch Source", .fetchSource),
    ("Schedule Expiration Warning", .scheduleExpirationWarningNotification),
]

struct OperationsLoggingControlView: View {
    @ObservedObject private var viewModel = OperationsLoggingViewModel()

    var body: some View {
        List {

            // Standalone Steps
            Section {

                ForEach(standaloneStepToggles, id: \.name) { entry in
                    stepToggle(entry.name, step: entry.step)
                }

            } header: {
                Text("STANDALONE STEPS")

            }.zLoaderSettingsRows()

            // Pipeline Steps
            Section {

                ForEach(pipelineStepToggles, id: \.name) { entry in
                    stepToggle(entry.name, step: entry.step)
                }

            } header: {
                Text("PIPELINE STEPS")

            }.zLoaderSettingsRows()

        }
        .background(Color(uiColor: .settingsBackground))
        .navigationTitle("Operations Logging")
        .zLoaderSettingsPage()
        .labelStyle(.titleAndIcon)
        #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func stepToggle(_ title: String, step: some OperationStep) -> some View {
        Toggle(
            isOn: Binding(
                get: { OperationsLoggingControl.isStepLoggingEnabled(for: step) },
                set: { value in
                    OperationsLoggingControl.setStepLoggingEnabled(for: step, value: value)
                    viewModel.refresh()
                }
            )
        ) { SettingsEntryLabel(title: title) }
        .tint(Color(uiColor: .altPrimary))
    }

}

private final class OperationsLoggingViewModel: ObservableObject {
    func refresh() {
        objectWillChange.send()
    }
}
