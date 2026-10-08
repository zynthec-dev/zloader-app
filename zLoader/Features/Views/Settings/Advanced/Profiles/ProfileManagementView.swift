//
//  ProfileManagementView.swift
//  ZLoader
//
//  Created by Magesh K on 14/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import CoreData
import SideSign
import UniformTypeIdentifiers

struct PendingProfileImport: Identifiable {
    let id = UUID()
    let profile: ALTProvisioningProfile
    let analysis: ProfileManager.CertificateAnalysisResult
}

struct ProfileManagementView: View {
    weak var presentingViewController: UIViewController?

    @StateObject private var viewModel = ProfileManagementViewModel()
    @StateObject private var certificatesViewModel = CertificatesViewModel()
    @StateObject private var devServicesViewModel = DeveloperServicesViewModel()

    @State private var searchText = ""
    @State private var showFileImporter = false
    @State private var profileToDelete: ALTProvisioningProfile? = nil
    @State private var showDeleteConfirmation = false
    @State private var showPortalDeleteConfirmation = false
    @State private var profileToShareURL: URL? = nil
    @State private var pendingImport: PendingProfileImport? = nil
    @State private var profileToEditOnPortal: ALTListedProvisioningProfile? = nil
    @State private var showAddOptions = false
    @State private var exportTargets: [ProfileExportTarget] = []

    private struct ProfileExportTarget: Identifiable {
        let id: String
        let name: String
        let directory: URL
    }

    private var allowedImportTypes: [UTType] {
        [UTType(filenameExtension: "mobileprovision"), .data].compactMap { $0 }
    }

    private var filteredProfiles: [ALTProvisioningProfile] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.profiles
        }
        return viewModel.profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.teamName.localizedCaseInsensitiveContains(searchText) ||
            $0.uuid.uuidString.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            List {
                Section(header: Text("App Profile Packages"), footer: Text("Exports the host and all cached extension profiles together, preserving each Apple signature. Profiles still require the matching private key, team, device and capabilities when reused.")) {
                    SwiftUI.Button("Export zLoader with Extensions and Backup") {
                        do { profileToShareURL = try ProfileManager.shared.exportOwnPackage() }
                        catch { viewModel.showToast(error.localizedDescription) }
                    }
                    ForEach(exportTargets) { target in
                        SwiftUI.Button("Export " + target.name + " with Extensions") {
                            do { profileToShareURL = try ProfileManager.shared.exportPackage(profileDirectory: target.directory) }
                            catch { viewModel.showToast(error.localizedDescription) }
                        }
                    }
                }.listRowBackground(ZLoaderGlassBackground())
                Section(header: Text("Overview")) {
                    LabeledContent("Total", value: String(viewModel.profiles.count))
                    LabeledContent("Ready") {
                        Text(String(viewModel.readyCount)).foregroundStyle(.green)
                    }
                    LabeledContent("Portal", value: String(viewModel.portalCount))
                    LabeledContent("Missing Cert") {
                        Text(String(viewModel.profiles.count - viewModel.readyCount))
                            .foregroundStyle(viewModel.profiles.count - viewModel.readyCount > 0 ? .orange : .secondary)
                    }
                }.listRowBackground(ZLoaderGlassBackground())

                Section(
                    header: Text("Provisioning Profiles (\(filteredProfiles.count))"),
                    footer: Text("Provisioning profiles dictate entitlements, device permissions, and expiration dates. Profiles sync automatically with your developer account.")
                ) {
                    if filteredProfiles.isEmpty {
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            Text(searchText.isEmpty ? "No provisioning profiles installed. Tap '+' to import or pull to refresh." : "No matching provisioning profiles found.")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                    } else {
                        ForEach(filteredProfiles, id: \.uuid) { profile in
                            NavigationLink(destination: ProvisioningProfileDetailView(profile: profile, profileURL: ProfileManager.shared.profileURL(for: profile.uuid), certificatesViewModel: certificatesViewModel)) {
                                ProfileManagementRowView(profile: profile, isRemote: viewModel.isRemoteProfile(profile), formatDate: formatDate)
                            }
                            #if !os(tvOS)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                SwiftUI.Button(role: .destructive) {
                                    promptDelete(profile)
                                } label: {
                                    SettingsEntryLabel(title: "Delete", systemImage: "trash")
                                }
                                if viewModel.canEditProfileOnPortal(profile) {
                                    SwiftUI.Button {
                                        if let listed = viewModel.listedProfile(for: profile.uuid) {
                                            profileToEditOnPortal = listed
                                        }
                                    } label: {
                                        SettingsEntryLabel(title: "Edit", systemImage: "pencil")
                                    }
                                    .tint(.purple)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                SwiftUI.Button {
                                    shareProfile(profile)
                                } label: {
                                    SettingsEntryLabel(title: "Share", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                            #endif
                            .contextMenu {
                                if viewModel.canEditProfileOnPortal(profile) {
                                    SwiftUI.Button {
                                        if let listed = viewModel.listedProfile(for: profile.uuid) {
                                            profileToEditOnPortal = listed
                                        }
                                    } label: {
                                        SettingsEntryLabel(title: "Edit on Developer Portal", systemImage: "pencil")
                                    }
                                }
                                SwiftUI.Button {
                                    shareProfile(profile)
                                } label: {
                                    SettingsEntryLabel(title: "Share Profile", systemImage: "square.and.arrow.up")
                                }
                                SwiftUI.Button(role: .destructive) {
                                    promptDelete(profile)
                                } label: {
                                    SettingsEntryLabel(title: "Delete Profile", systemImage: "trash")
                                }
                            }
                        }
                    }
                }.listRowBackground(ZLoaderGlassBackground())
            }
            #if !os(tvOS)
            .listStyle(InsetGroupedListStyle())
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search Profiles")
            #else
            .listStyle(GroupedListStyle())
            #endif

            if let message = viewModel.toastMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(20)
                        .shadow(radius: 6)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: viewModel.toastMessage)
            }
        }
        .navigationTitle("Profile Management")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    showAddOptions = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Provisioning Profile")
            }
        }
        .onAppear {
            viewModel.loadProfiles(isPullToRefresh: false)
            let context = DatabaseManager.shared.persistentContainer.viewContext
            context.perform {
                let request = NSFetchRequest<InstalledApp>(entityName: "InstalledApp")
                if let apps = try? context.fetch(request) {
                    exportTargets = apps.filter { !$0.resignedBundleIdentifier.isZLoaderAppID }.map {
                        ProfileExportTarget(id: $0.resignedBundleIdentifier, name: $0.name,
                                            directory: $0.directoryURL.appendingPathComponent("ProvisioningProfiles"))
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadProfiles(isPullToRefresh: true)
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedImportTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                handleFileSelected(at: url)
            case .failure(let error):
                viewModel.showToast("Import canceled: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: Binding<Bool>(
            get: { profileToShareURL != nil },
            set: { if !$0 { profileToShareURL = nil } }
        )) {
            if let url = profileToShareURL {
                ActivityViewController(activityItems: [url])
            }
        }
        #endif
        .sheet(item: $profileToEditOnPortal) { listed in
            NavigationView {
                ProfilePortalDetailView(profile: listed, viewModel: devServicesViewModel, presentingViewController: presentingViewController)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            SwiftUI.Button("Done") {
                                profileToEditOnPortal = nil
                                viewModel.loadProfiles(isPullToRefresh: true)
                            }
                        }
                    }
            }
        }
        .alert(item: $pendingImport) { pending in
            switch pending.analysis {
            case .signable(let certName, _):
                return Alert(
                    title: Text("Link Signing Certificate?"),
                    message: Text("Found matching signing certificate '\(certName)' with private key in zLoader.\n\nWould you like to link and save this profile?"),
                    primaryButton: .default(Text("Link & Save")) {
                        commitImport(pending.profile)
                    },
                    secondaryButton: .cancel()
                )
            case .publicOnly(let certName, _):
                return Alert(
                    title: Text("Missing Private Key"),
                    message: Text("Found certificate '\(certName)' in this profile, but no matching private key (.p12) was found in zLoader.\n\nContinuing means this profile will not be usable for signing apps until a matching signing certificate with private key is imported."),
                    primaryButton: .destructive(Text("Import Anyway")) {
                        commitImport(pending.profile)
                    },
                    secondaryButton: .cancel()
                )
            case .noMatch(let count):
                return Alert(
                    title: Text("No Matching Signing Certificate"),
                    message: Text("This provisioning profile contains \(count) developer certificate(s), but none match any signing certificates in zLoader.\n\nContinuing means this profile will not be usable for signing apps until a matching signing certificate with private key is imported."),
                    primaryButton: .destructive(Text("Import Anyway")) {
                        commitImport(pending.profile)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Local Profile?"),
                message: Text("Are you sure you want to delete '\(profileToDelete?.name ?? "this profile")' from local storage? Any apps assigned to this profile will revert to default."),
                primaryButton: .destructive(Text("Delete")) {
                    if let target = profileToDelete {
                        Task {
                            await viewModel.deleteProfile(target, alsoDeleteFromPortal: false)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Delete Portal Profile?", isPresented: $showPortalDeleteConfirmation) {
            SwiftUI.Button("Delete from Portal & Locally", role: .destructive) {
                if let target = profileToDelete {
                    Task {
                        await viewModel.deleteProfile(target, alsoDeleteFromPortal: true)
                    }
                }
            }
            SwiftUI.Button("Delete Locally Only") {
                if let target = profileToDelete {
                    Task {
                        await viewModel.deleteProfile(target, alsoDeleteFromPortal: false)
                    }
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("'\((profileToDelete?.name ?? "This profile"))' exists on the Apple Developer Portal. Do you want to delete it from Apple's servers as well, or only delete the local cache?")
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            SwiftUI.Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .confirmationDialog("Add Provisioning Profile", isPresented: $showAddOptions, titleVisibility: .visible) {
            SwiftUI.Button("Import from Files") {
                importProfileAction()
            }
            SwiftUI.Button("Create on Developer Portal") {
                Task {
                    await devServicesViewModel.loadAll(presentingViewController: presentingViewController)
                }
                let controller = ZLoaderHostingController(rootView: ProfilesListView(viewModel: devServicesViewModel, presentingViewController: presentingViewController), usesGlass: false)
                presentingViewController?.navigationController?.pushViewController(controller, animated: true)
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        }
        .onAppear { viewModel.loadProfiles(isPullToRefresh: true) }
    }

    private func handleFileSelected(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "zloaderprofiles" {
                let count = try ProfileManager.shared.importPackage(data: data)
                viewModel.loadProfiles(isPullToRefresh: false)
                viewModel.showToast("Imported \(count) signed profiles. Matching certificates with private keys are still required.")
                return
            }
            let profile = try ALTProvisioningProfile(data: data)
            let analysis = ProfileManager.shared.analyzeCertificates(for: profile)
            self.pendingImport = PendingProfileImport(profile: profile, analysis: analysis)
        } catch {
            viewModel.showToast("Invalid provisioning profile: \(error.localizedDescription)")
        }
    }

    private func commitImport(_ profile: ALTProvisioningProfile) {
        do {
            _ = try ProfileManager.shared.importProfile(data: profile.data)
            viewModel.loadProfiles(isPullToRefresh: false)
            viewModel.showToast("Imported '\(profile.name)' successfully")
        } catch {
            viewModel.showToast("Failed to import profile: \(error.localizedDescription)")
        }
    }

    private func promptDelete(_ profile: ALTProvisioningProfile) {
        profileToDelete = profile
        if viewModel.isRemoteProfile(profile) {
            showPortalDeleteConfirmation = true
        } else {
            showDeleteConfirmation = true
        }
    }

    private func importProfileAction() {
        #if !os(tvOS)
        showFileImporter = true
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["mobileprovision"],
            title: "Import Provisioning Profile",
            presentingVC: topVC
        ) { fileURL in
            guard let fileURL = fileURL else { return }
            handleFileSelected(at: fileURL)
        }
        #endif
    }

    private func shareProfile(_ profile: ALTProvisioningProfile) {
        let fileURL = ProfileManager.shared.profileURL(for: profile.uuid)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        #if !os(tvOS)
        profileToShareURL = fileURL
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startExport(
            fileURL: fileURL,
            title: "Export Provisioning Profile",
            presentingVC: topVC,
            completion: nil
        )
        #endif
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct ProfileManagementRowView: View {
    let profile: ALTProvisioningProfile
    let isRemote: Bool
    let formatDate: (Date) -> String

    private var isExpired: Bool {
        profile.expirationDate < Date()
    }

    private var matchingCert: ALTCertificate? {
        ProfileManager.shared.getMatchingCertificate(for: profile)
    }

    private var assignedApps: [String] {
        ProfileManager.shared.getAppsUsingProfile(uuid: profile.uuid)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: profile.name).font(.body).foregroundStyle(.primary)
            Text(verbatim: profile.bundleIdentifier).font(.footnote).foregroundStyle(.secondary)
            HStack {
                Text(isRemote ? "Portal" : "Local")
                Spacer()
                Text("Expires: \(formatDate(profile.expirationDate))")
            }.font(.footnote).foregroundStyle(.secondary)
            Text(isExpired ? "Expired" : matchingCert != nil ? "Ready" : "No Key")
                .font(.footnote)
                .foregroundStyle(isExpired ? .red : matchingCert != nil ? .green : .orange)
            if let cert = matchingCert {
                Text("Signer: \(cert.name)").font(.footnote).foregroundStyle(.secondary)
            }
            if !assignedApps.isEmpty {
                Text("Assigned: \(assignedApps.joined(separator: ", "))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
