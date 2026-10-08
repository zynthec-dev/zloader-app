//
//  AppIDDetailView.swift
//  ZLoader
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct AppIDDetailView: View {
    let appID: ALTAppID
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?

    @State private var editedName = ""
    @State private var hasModifiedName = false
    @State private var selectedGroupIDs: Set<String> = []
    @State private var hasModifiedGroups = false
    @State private var isSaving = false
    @State private var hasInitializedGroups = false
    @State private var editedFeatures: [Feature: String] = [:]
    @State private var hasModifiedFeatures = false

    init(appID: ALTAppID, viewModel: DeveloperServicesViewModel, presentingViewController: UIViewController? = nil) {
        self.appID = appID
        self.viewModel = viewModel
        self.presentingViewController = presentingViewController
    }

    private var currentAppID: ALTAppID {
        viewModel.appIDs.first(where: { $0.identifier == appID.identifier }) ?? appID
    }

    var body: some View {
        List {
            Section(header: Text("App ID Metadata")) {
                TextField("Name", text: $editedName)
                    .onChange(of: editedName) { _, value in hasModifiedName = value != currentAppID.name }
                InfoRow(label: "Bundle Identifier", value: currentAppID.bundleIdentifier)
                InfoRow(label: "App ID (Identifier)", value: currentAppID.identifier)
                if let expiration = currentAppID.expirationDate {
                    InfoRow(label: "Expiration Date", value: formatDate(expiration), valueColor: expiration < Date() ? .red : .primary)
                }
            }.listRowBackground(ZLoaderGlassBackground())

            Section(header: Text("Capabilities & Features (\(currentAppID.features.count))")) {
                ForEach(Array(viewModel.team?.type.allowedFeatures ?? []).sorted { $0.rawValue < $1.rawValue }, id: \.rawValue) { feature in
                    Toggle(displayName(for: feature), isOn: Binding(
                        get: { (editedFeatures[feature] ?? currentAppID.features[feature]) == "true" },
                        set: { editedFeatures[feature] = $0 ? "true" : "false"; hasModifiedFeatures = true }
                    ))
                    .disabled(viewModel.isActionLoading || isSaving)
                }
                if currentAppID.features.isEmpty {
                    Text("No special features enabled for this App ID.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    let sortedFeatures = currentAppID.features.sorted { $0.key.rawValue < $1.key.rawValue }
                    ForEach(sortedFeatures, id: \.key.rawValue) { feature, value in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayName(for: feature))
                                    .font(.subheadline)
                                Text(feature.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(value)
                                .font(.caption)
                                .foregroundColor(value == "true" ? .green : .secondary)
                        }
                    }
                }
            }.listRowBackground(ZLoaderGlassBackground())

            Section(header: Text("Associated App Groups"), footer: Text("The portal API does not return the current group assignments. No groups are preselected. Select the complete desired set before saving; this replaces the associations.")) {
                if viewModel.appGroups.isEmpty {
                    Text("No App Groups available on this team. Create an App Group first.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.appGroups, id: \.identifier) { group in
                        SwiftUI.Button {
                            if selectedGroupIDs.contains(group.identifier) {
                                selectedGroupIDs.remove(group.identifier)
                            } else {
                                selectedGroupIDs.insert(group.identifier)
                            }
                            hasModifiedGroups = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(group.identifier)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedGroupIDs.contains(group.identifier) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .imageScale(.large)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                        .imageScale(.large)
                                }
                            }
                        }
                    }


                }
            }.listRowBackground(ZLoaderGlassBackground())

            Section(header: Text("Actions")) {
                SwiftUI.Button {
                    Task {
                        _ = await viewModel.downloadProfile(for: currentAppID, presentingViewController: presentingViewController)
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Download Provisioning Profile")
                    }
                }
            }.listRowBackground(ZLoaderGlassBackground())
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle(currentAppID.name.isEmpty ? "App ID Details" : currentAppID.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SwiftUI.Button {
                    Task { await saveChanges() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                    }
                }
                .accessibilityLabel(Text("Save Changes"))
                .disabled(isSaving || viewModel.isActionLoading || !(hasModifiedFeatures || hasModifiedGroups || hasModifiedName) || editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .disabled(isSaving)
        .labelStyle(.titleOnly)
        .onAppear {
            if !hasModifiedName { editedName = currentAppID.name }
            initializeSelectedGroups()
        }
        .refreshable {
            async let fetchIDs: () = viewModel.fetchAppIDs(presentingViewController: presentingViewController, isPullToRefresh: true)
            async let fetchGroups: () = viewModel.fetchAppGroups(presentingViewController: presentingViewController, isPullToRefresh: true)
            _ = await (fetchIDs, fetchGroups)
        }
        .developerServicesToast(viewModel: viewModel)
    }

    @MainActor
    private func saveChanges() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        // Apple exposes separate mutations. Keep unsaved changes when either fails;
        // successfully saved capabilities are not submitted again on a retry.
        if hasModifiedFeatures || hasModifiedName {
            guard await viewModel.updateCapabilities(for: currentAppID, features: editedFeatures,
                name: editedName.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            editedFeatures = [:]
            hasModifiedFeatures = false
            hasModifiedName = false
        }
        if hasModifiedGroups {
            let groups = viewModel.appGroups.filter { selectedGroupIDs.contains($0.identifier) }
            guard await viewModel.updateAppGroups(for: currentAppID, to: groups,
                presentingViewController: presentingViewController) else { return }
            hasModifiedGroups = false
        }
    }

    private func initializeSelectedGroups() {
        guard !hasInitializedGroups else { return }
        hasInitializedGroups = true
        let initial = Set<String>()
        // The portal's feature flag does not identify associated groups. Never
        // preselect every group in the team from a single enabled capability.
        self.selectedGroupIDs = initial
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func displayName(for feature: Feature) -> String {
        switch feature {
        case .appGroups: return "App Groups"
        case .gameCenter: return "Game Center"
        case .inAppPurchase: return "In-App Purchase"
        case .pushNotifications: return "Push Notifications"
        case .interAppAudio: return "Inter-App Audio"
        case .associatedDomains: return "Associated Domains"
        case .dataProtection: return "Data Protection"
        case .siri: return "Siri"
        case .applePay: return "Apple Pay"
        case .vpn: return "Personal VPN"
        case .networkExtensions: return "Network Extensions"
        case .multipath: return "Multipath"
        case .hotspot: return "Hotspot"
        case .nfc: return "NFC Tag Reading"
        case .classKit: return "ClassKit"
        case .autoFillCredentialProvider: return "AutoFill Credential Provider"
        case .accessWiFiInformation: return "Access WiFi Information"
        case .wirelessAccessoryConfiguration: return "Wireless Accessory Config"
        case .increasedMemoryLimit: return "Increased Memory Limit"
        case .extendedVirtualAddressing: return "Extended Virtual Addressing"
        case .increasedDebuggingMemoryLimit: return "Increased Debugging Memory Limit"
        default: return feature.rawValue
        }
    }
}

struct AppIDInfoView: View {
    let appID: ALTAppID
    var body: some View {
        List {
            Section("App ID Metadata") {
                LabeledContent("Name", value: appID.name)
                LabeledContent("Bundle Identifier", value: appID.bundleIdentifier)
                LabeledContent("App ID (Identifier)", value: appID.identifier)
                if let expiration = appID.expirationDate { LabeledContent("Expires") { Text(expiration, style: .date) } }
            }.listRowBackground(ZLoaderGlassBackground())
            Section("Capabilities & Features") {
                ForEach(appID.features.sorted { $0.key.rawValue < $1.key.rawValue }, id: \.key.rawValue) { feature, value in
                    LabeledContent(feature.rawValue, value: value)
                }
            }.listRowBackground(ZLoaderGlassBackground())
            Section("Requested Entitlements") {
                ForEach(appID.entitlements.sorted { $0.key < $1.key }, id: \.key) { key, value in
                    LabeledContent(key, value: value)
                }
            }.listRowBackground(ZLoaderGlassBackground())
        }.navigationTitle("App ID Details").textSelection(.enabled)
    }
}
