//
//  OperationsLoggingControlView.swift
//  ZLoader
//
//  Created by Magesh K on 14/01/25.
//  Copyright © 2025 SideStore. All rights reserved.
//

import SwiftUI

private extension Color {
    static var settingsRowBackground: Color { Color(uiColor: .settingsCard) }
    static var settingsDivider: Color { Color(uiColor: .separator) }
}

private let pipelineStepToggles: [(name: String, step: PipelineStep)] = [
    ("Backup App Data",                         .backupAppData),
    ("Cache App",                               .cacheApp),
    ("Change App Icon",                         .changeAppIcon),
    ("Clean Staged App",                        .cleanStagedApp),
    ("Deactivate App",                          .deactivateApp),
    ("Download App",                            .downloadApp),
    ("Export Resigned IPA",                     .exportResignedIPA),
    ("Fetch Provisioning Profiles",             .fetchProvisioningProfiles),
    ("Install App",                             .installApp),
    ("Preflight Checks",                        .preflightChecks),
    ("Prepare App Extension Bundle IDs",        .prepareAppExtensionBundleIDs),
    ("Refresh App",                             .refreshApp),
    ("Remove App",                              .removeApp),
    ("Remove App Extensions",                   .removeAppExtensions),
    ("Remove Backup Data",                      .removeBackupData),
    ("Resign App",                              .resignApp),
    ("Restore App Data",                        .restoreAppData),
    ("Send App",                                .sendApp),
    ("Stage App",                               .stageApp),
    ("Stage Backup App",                        .stageBackupApp),
    ("Update App Certificate",                  .updateAppCertificate),
    ("User Customization",                      .userCustomization),
    ("Verify App",                              .verifyApp),
    ("Verify Certificate",                      .verifyCertificate),
    ("Create IPA",                              .createIPA),
]

private let standaloneStepToggles: [(name: String, step: StandaloneStep)] = [
    ("Sign In",                                 .signIn),
    ("Background Refresh Apps",                 .backgroundRefreshApps),
    ("Clear App Cache",                         .clearAppCache),
    ("Enable JIT",                              .enableJIT),
    ("Sync App IDs",                            .syncAppIDs),
    ("Fetch Source",                            .fetchSource),
    ("Schedule Expiration Warning",             .scheduleExpirationWarningNotification),
]

struct OperationsLoggingControlView: View {
    @ObservedObject private var viewModel = OperationsLoggingViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Standalone Steps
                VStack(alignment: .leading, spacing: 8) {
                    Text("STANDALONE STEPS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.secondary)
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(standaloneStepToggles.enumerated()), id: \.element.name) { index, entry in
                            if index > 0 {
                                divider
                            }
                            stepToggle(entry.name, step: entry.step)
                        }
                    }
                    .zLoaderGlassSurface()
                    .cornerRadius(12)
                }
                
                // Pipeline Steps
                VStack(alignment: .leading, spacing: 8) {
                    Text("PIPELINE STEPS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.secondary)
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(pipelineStepToggles.enumerated()), id: \.element.name) { index, entry in
                            if index > 0 {
                                divider
                            }
                            stepToggle(entry.name, step: entry.step)
                        }
                    }
                    .zLoaderGlassSurface()
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .settingsBackground))
        .navigationTitle("Operations Logging")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func stepToggle(_ title: String, step: some OperationStep) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Toggle("", isOn: Binding(
                get: { OperationsLoggingControl.isStepLoggingEnabled(for: step) },
                set: { value in
                    OperationsLoggingControl.setStepLoggingEnabled(for: step, value: value)
                    viewModel.refresh()
                }
            ))
            .labelsHidden()
            .tint(Color(uiColor: .altPrimary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.settingsDivider)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}

private final class OperationsLoggingViewModel: ObservableObject {
    func refresh() {
        objectWillChange.send()
    }
}
