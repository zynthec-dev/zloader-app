//
//  AppIDsListView.swift
//  ZLoader
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct AppIDsListView: View {
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?

    @State private var selectedAppID: ALTAppID?
    @State private var showInfo = false
    @State private var showEditor = false
    @State private var showProfile = false
    @State private var searchText = ""
    @State private var showRegisterSheet = false
    @State private var newAppIDName = ""
    @State private var newAppIDBundleID = ""

    @State private var appIDToDelete: ALTAppID? = nil
    @State private var showDeleteConfirmation = false

    private var filteredAppIDs: [ALTAppID] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.appIDs
        }
        return viewModel.appIDs.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.identifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section(header: Text("Registered App IDs (\(viewModel.appIDs.count))")) {
                if filteredAppIDs.isEmpty {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(searchText.isEmpty ? "No App IDs registered on Developer Portal." : "No matching App IDs found.")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                } else {
                    ForEach(filteredAppIDs, id: \.identifier) { appID in
                        NavigationLink(destination: AppIDDetailView(appID: appID, viewModel: viewModel, presentingViewController: presentingViewController)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(appID.name.isEmpty ? "App ID" : appID.name)
                                        .font(.body)
                                    Spacer()
                                    if !appID.features.isEmpty {
                                        Text("\(appID.features.count) features")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(6)
                                    }
                                }
                                Text(appID.bundleIdentifier)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("ID: \(appID.identifier)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if let expiration = appID.expirationDate {
                                        Text("Expires: \(formatDate(expiration))")
                                            .font(.caption)
                                            .foregroundColor(expiration < Date() ? .red : .secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        #if !os(tvOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            SwiftUI.Button(role: .destructive) {
                                appIDToDelete = appID
                                showDeleteConfirmation = true
                            } label: {
                                SettingsEntryLabel(title: "Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            SwiftUI.Button("Info") { selectedAppID = appID; showInfo = true }.tint(.gray)
                            SwiftUI.Button("Edit") { selectedAppID = appID; showEditor = true }.tint(.accentColor)
                            SwiftUI.Button("Create Profile") { selectedAppID = appID; showProfile = true }.tint(.accentColor)
                        }
                        #endif
                        .contextMenu {
                            SwiftUI.Button("Info") { selectedAppID = appID; showInfo = true }
                            SwiftUI.Button("Edit") { selectedAppID = appID; showEditor = true }
                            SwiftUI.Button("Create Profile") { selectedAppID = appID; showProfile = true }
                            SwiftUI.Button(role: .destructive) {
                                appIDToDelete = appID
                                showDeleteConfirmation = true
                            } label: {
                                SettingsEntryLabel(title: "Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }.listRowBackground(ZLoaderGlassBackground())
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search App IDs")
        #else
        .listStyle(GroupedListStyle())
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: PortalSelectionView(viewModel: viewModel, kind: .appIDs)) {
                    Label("Select", systemImage: "checklist")
                }
            }
        }
        .navigationTitle("App IDs")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    showRegisterSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.fetchAppIDs(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .sheet(isPresented: $showRegisterSheet) {
            NavigationView {
                Form {
                    Section(header: Text("App ID Information"), footer: Text("Bundle ID must match reverse-DNS format (e.g. com.example.myapp).")) {
                        TextField("Name (e.g. My App)", text: $newAppIDName)
                        TextField("Bundle Identifier", text: $newAppIDBundleID)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }.listRowBackground(ZLoaderGlassBackground())
                }
                .navigationTitle("Register App ID")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
                .navigationBarItems(
                    leading: SwiftUI.Button("Cancel") {
                        newAppIDName = ""
                        newAppIDBundleID = ""
                        showRegisterSheet = false
                    },
                    trailing: SwiftUI.Button("Register") {
                        let name = newAppIDName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let bundleID = newAppIDBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty, !bundleID.isEmpty else { return }
                        Task {
                            let success = await viewModel.createAppID(name: name, bundleIdentifier: bundleID, presentingViewController: presentingViewController)
                            if success {
                                newAppIDName = ""
                                newAppIDBundleID = ""
                                showRegisterSheet = false
                            }
                        }
                    }
                    .disabled(newAppIDName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newAppIDBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              viewModel.isActionLoading)
                )
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(viewModel.isPaidAccount ? "Delete App ID?" : "Warning: Delete App ID?"),
                message: Text(deleteAlertMessage),
                primaryButton: .destructive(Text("Delete")) {
                    if let target = appIDToDelete {
                        Task {
                            _ = await viewModel.deleteAppID(target, presentingViewController: presentingViewController)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showInfo) {
            NavigationStack { if let appID = selectedAppID {
                AppIDInfoView(appID: appID)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { SwiftUI.Button("Done") { showInfo = false } } }
            } }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { if let appID = selectedAppID {
                AppIDDetailView(appID: appID, viewModel: viewModel, presentingViewController: presentingViewController)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { SwiftUI.Button("Done") { showEditor = false } } }
            } }
        }
        .sheet(isPresented: $showProfile) {
            CreateManualProfileView(viewModel: viewModel, presentingViewController: presentingViewController,
                appIDIdentifier: selectedAppID?.identifier ?? "")
        }
        .developerServicesToast(viewModel: viewModel)
    }

    private var deleteAlertMessage: String {
        guard let appID = appIDToDelete else { return "" }
        let name = appID.name.isEmpty ? "this App ID" : "'\(appID.name)'"
        let bundleID = appID.bundleIdentifier.isEmpty ? "" : " (\(appID.bundleIdentifier))"

        if viewModel.isPaidAccount {
            return "Are you sure you want to delete \(name)\(bundleID)? This will also remove any associated provisioning profiles."
        }

        var expiryNotice = "until it expires automatically after the remaining days of its usual 7-day validity."
        if let expiration = appID.expirationDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: expiration)
            if let days = components.day, days > 0 {
                expiryNotice = "until it expires automatically in \(days) day\(days == 1 ? "" : "s") (from its usual 7-day validity)."
            }
        }

        return "Warning: Deleting \(name)\(bundleID) does not free up an App ID slot.\n\nThis App ID will become reserved and will not be available for use \(expiryNotice)\n\nAre you sure you want to delete it?"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
