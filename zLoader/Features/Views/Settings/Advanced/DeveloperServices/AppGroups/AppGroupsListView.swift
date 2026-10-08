//
//  AppGroupsListView.swift
//  ZLoader
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct AppGroupsListView: View {
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?

    @State private var groupForInfo: ALTAppGroup?
    @State private var showInfo = false
    @State private var showProfile = false
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var newGroupName = ""
    @State private var newGroupIdentifier = "group."

    @State private var groupToEdit: ALTAppGroup? = nil
    @State private var editGroupName = ""
    @State private var showSheetDeleteConfirmation = false

    @State private var groupToDelete: ALTAppGroup? = nil
    @State private var showDeleteConfirmation = false

    private var filteredGroups: [ALTAppGroup] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.appGroups
        }
        return viewModel.appGroups.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.groupIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.identifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section(header: Text("App Groups (\(viewModel.appGroups.count))"), footer: Text("App Groups enable data sharing across multiple apps and extensions within the same developer team. Tap a group to edit its name or delete it.")) {
                if filteredGroups.isEmpty {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(searchText.isEmpty ? "No App Groups found on Developer Portal." : "No matching App Groups found.")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                } else {
                    ForEach(filteredGroups, id: \.identifier) { group in
                        SwiftUI.Button {
                            editGroupName = group.name
                            groupToEdit = group
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(group.name.isEmpty ? "App Group" : group.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(group.groupIdentifier)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("Group ID: \(group.identifier)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        #if !os(tvOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            SwiftUI.Button(role: .destructive) {
                                groupToDelete = group
                                showDeleteConfirmation = true
                            } label: {
                                SettingsEntryLabel(title: "Delete", systemImage: "trash")
                            }

                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            SwiftUI.Button("Info") { groupForInfo = group; showInfo = true }.tint(.gray)
                            SwiftUI.Button("Create Profile") { showProfile = true }.tint(.accentColor)
                            SwiftUI.Button {
                                editGroupName = group.name
                                groupToEdit = group
                            } label: {
                                SettingsEntryLabel(title: "Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        #endif
                        .contextMenu {
                            SwiftUI.Button("Info") { groupForInfo = group; showInfo = true }.tint(.gray)
                            SwiftUI.Button("Create Profile") { showProfile = true }.tint(.accentColor)
                            SwiftUI.Button {
                                editGroupName = group.name
                                groupToEdit = group
                            } label: {
                                SettingsEntryLabel(title: "Edit Name", systemImage: "pencil")
                            }
                            #if !os(tvOS)
                            SwiftUI.Button {
                                UIPasteboard.general.string = group.groupIdentifier
                            } label: {
                                SettingsEntryLabel(title: "Copy Identifier", systemImage: "doc.on.doc")
                            }
                            #endif
                            SwiftUI.Button(role: .destructive) {
                                groupToDelete = group
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
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search App Groups")
        #else
        .listStyle(GroupedListStyle())
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: PortalSelectionView(viewModel: viewModel, kind: .appGroups)) {
                    Label("Select", systemImage: "checklist")
                }
            }
        }
        .navigationTitle("App Groups")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    newGroupName = ""
                    newGroupIdentifier = "group."
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.fetchAppGroups(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationView {
                Form {
                    Section(header: Text("App Group Details"), footer: Text("Group identifier must start with 'group.' prefix (e.g. group.com.example.shared).")) {
                        TextField("Name (e.g. Shared Storage)", text: $newGroupName)
                        TextField("Group Identifier", text: $newGroupIdentifier)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }.listRowBackground(ZLoaderGlassBackground())
                }
                .navigationTitle("Create App Group")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
                .navigationBarItems(
                    leading: SwiftUI.Button("Cancel") {
                        showCreateSheet = false
                    },
                    trailing: SwiftUI.Button("Create") {
                        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let groupID = newGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty, !groupID.isEmpty else { return }
                        Task {
                            let success = await viewModel.createAppGroup(name: name, groupIdentifier: groupID, presentingViewController: presentingViewController)
                            if success {
                                showCreateSheet = false
                            }
                        }
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              !newGroupIdentifier.hasPrefix("group.") ||
                              viewModel.isActionLoading)
                )
            }
        }
        .sheet(item: $groupToEdit) { group in
            NavigationView {
                Form {
                    Section(header: Text("Description"), footer: Text("You cannot use special characters such as @, &, *, ', \", -, .")) {
                        TextField("Description", text: $editGroupName)
                    }.listRowBackground(ZLoaderGlassBackground())

                    Section(header: Text("Identifier")) {
                        Text(group.groupIdentifier)
                            .foregroundColor(.secondary)
                    }.listRowBackground(ZLoaderGlassBackground())

                    Section {
                        SwiftUI.Button(role: .destructive) {
                            showSheetDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Remove App Group")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }.listRowBackground(ZLoaderGlassBackground())
                }
                .navigationTitle("Edit Identifier Configuration")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
                .navigationBarItems(
                    leading: SwiftUI.Button("Cancel") {
                        groupToEdit = nil
                    },
                    trailing: SwiftUI.Button {
                        let trimmed = editGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            let success = await viewModel.updateAppGroup(group, newName: trimmed, presentingViewController: presentingViewController)
                            if success {
                                groupToEdit = nil
                            }
                        }
                    }
                    label: {
                        if viewModel.isActionLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                        }
                    }
                    .accessibilityLabel(Text("Save Changes"))
                    .disabled(editGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              editGroupName == group.name ||
                              viewModel.isActionLoading)
                )
                .alert(isPresented: $showSheetDeleteConfirmation) {
                    Alert(
                        title: Text("Delete App Group?"),
                        message: Text("Are you sure you want to delete '\(group.name)' (\(group.groupIdentifier)) from Apple Developer Portal?"),
                        primaryButton: .destructive(Text("Delete")) {
                            Task {
                                let success = await viewModel.deleteAppGroup(group, presentingViewController: presentingViewController)
                                if success {
                                    groupToEdit = nil
                                }
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete App Group?"),
                message: Text("Are you sure you want to delete '\(groupToDelete?.name ?? "this App Group")' (\(groupToDelete?.groupIdentifier ?? "")) from Apple Developer Portal?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let target = groupToDelete {
                        Task {
                            _ = await viewModel.deleteAppGroup(target, presentingViewController: presentingViewController)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showInfo) {
            NavigationStack {
                List { if let group = groupForInfo {
                    Section("App Group") {
                        LabeledContent("Name", value: group.name)
                        LabeledContent("Identifier", value: group.groupIdentifier)
                        LabeledContent("Group ID", value: group.identifier)
                    }.listRowBackground(ZLoaderGlassBackground())
                } }.navigationTitle("Info")
                .zLoaderSettingsPage()
                .toolbar { ToolbarItem(placement: .confirmationAction) { SwiftUI.Button("Done") { showInfo = false } } }
            }
        }
        .sheet(isPresented: $showProfile) {
            CreateManualProfileView(viewModel: viewModel, presentingViewController: presentingViewController)
        }
        .developerServicesToast(viewModel: viewModel)
    }
}
