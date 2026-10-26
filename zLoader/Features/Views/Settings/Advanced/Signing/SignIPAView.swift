import SwiftUI
import UniformTypeIdentifiers

struct SignIPAView: View {
    var onInstall: ((URL) -> Void)? = nil
    @ObservedObject private var identities = SigningIdentityStore.shared
    @State private var preparation: SignIPAPreparation?
    @State private var customization = SigningCustomizationOptions()
    @State private var identityID: UUID?
    @State private var method: SigningMethod = AuthManager.shared.isAuthenticated ? .appleAccount : .importedCertificate
    @State private var ipa: URL?
    @State private var importingIPA = false
    @State private var importingProfiles = false
    @State private var isSigning = false
    @State private var result: URL?
    @State private var errorMessage: String?

    private var canUseSigningMethod: Bool {
        if method == .appleAccount { return AuthManager.shared.isAuthenticated }
        return identityID.map { selected in identities.identities.contains { $0.id == selected } } ?? false
    }

    private func selectOfflineIdentityIfNeeded() {
        if identityID == nil {
            identityID = identities.pipelineIdentityID ?? identities.identities.first?.id
        }
    }

    var body: some View {
        List {
            Section("IPA") {
                SwiftUI.Button(ipa?.lastPathComponent ?? NSLocalizedString("Choose IPA", comment: "")) { importingIPA = true }
            }.zLoaderSettingsRows()
            Section("Edit Before Signing") {
                Toggle("Customize Info.plist", isOn: $customization.infoPlist)
                Toggle("Customize App ID", isOn: $customization.appID).disabled(customization.infoPlist)
                Toggle("Customize Entitlements", isOn: $customization.entitlements)
                Toggle("Customize App Icon", isOn: $customization.icon)
                Toggle("Customize Provisioning Profile", isOn: $customization.profile)
                Picker("Customize Extensions", selection: $customization.extensions) {
                    ForEach(AppExtensionCustomization.allCases) { option in
                        Text(LocalizedStringKey(option.displayName), tableName: "AppActions").tag(option)
                    }
                }
                SwiftUI.Button("Edit App") { Task { await editApp() } }.disabled(ipa == nil || !canUseSigningMethod)
                if preparation != nil { Text("Changes ready for signing").foregroundStyle(.secondary) }
            }.zLoaderSettingsRows()
            Section("Sign With") {
                Picker("Signing Method", selection: $method) {
                    Text("Apple Account", tableName: "AppActions").tag(SigningMethod.appleAccount)
                    Text("Imported Certificate", tableName: "AppActions").tag(SigningMethod.importedCertificate)
                }
                .accessibilityIdentifier("signing-method")
                if method == .importedCertificate {
                    if !identities.identities.isEmpty {
                        Picker("Signing Identity", selection: $identityID) {
                            Text("Choose Signing Identity", tableName: "AppActions").tag(nil as UUID?)
                            ForEach(identities.identities) { identity in
                                Text(verbatim: identity.name).tag(Optional(identity.id))
                            }
                        }
                    }
                    NavigationLink {
                        SigningIdentityEditor { identity in identityID = identity.id }
                    } label: { Label { Text("Choose Certificate & Profiles", tableName: "AppActions") } icon: { Image(systemName: "person.badge.key") } }
                        .accessibilityIdentifier("signing-import-identity")
                }
                NavigationLink { SigningIdentitiesView() } label: { SettingsEntryLabel(title: "Signing Identities") }
                if method == .importedCertificate {
                    Text("No Apple Account is required when you use an imported certificate with its private key and matching profiles.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if !AuthManager.shared.isAuthenticated {
                    Text("Sign in to use an Apple Account, or choose Imported Certificate.", tableName: "AppActions")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if method == .importedCertificate && identityID != nil {
                    SwiftUI.Button("Import Additional Profiles") { importingProfiles = true }
                }
            }.zLoaderSettingsRows()
            Section {
                SwiftUI.Button("Sign App") { Task { await sign() } }
                    .disabled(ipa == nil || isSigning || !canUseSigningMethod)
                if isSigning { ProgressView("Signing…") }
                if let result {
                    ShareLink("Share Signed IPA", item: result)
                    NavigationLink { CacheManagementView(signedIPAsOnly: true, onInstall: onInstall) } label: { SettingsEntryLabel(title: "IPA Library") }
                }
            } footer: {
                Group {
                    Text("Signing without installation always saves the IPA in Signed IPAs. The receiving device must be authorized by every embedded profile. A wildcard profile does not grant additional capabilities.")
                }
            }.zLoaderSettingsRows()
        }
        .navigationTitle("Sign App")
        .zLoaderSettingsPage()
        .labelStyle(.titleAndIcon)
        .disabled(isSigning)
        .onAppear {
            if identities.pipelineMethod == .importedCertificate { method = .importedCertificate }
            selectOfflineIdentityIfNeeded()
        }
        .onChange(of: identities.identities) { _, _ in selectOfflineIdentityIfNeeded() }
        .onChange(of: identityID) { _, _ in preparation = nil; result = nil }
        .onChange(of: method) { _, _ in preparation = nil; result = nil }
        .fileImporter(isPresented: $importingIPA, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]) { selection in
            do { ipa = try selection.get(); result = nil; preparation = nil } catch { errorMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $importingProfiles, allowedContentTypes: [.data], allowsMultipleSelection: true) { selection in
            do {
                guard let identityID, var identity = identities.identities.first(where: { $0.id == identityID }) else { return }
                for url in try selection.get() {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let profile = try ProfileManager.shared.importProfile(from: url)
                    if !identity.profileIDs.contains(profile.uuid) { identity.profileIDs.append(profile.uuid) }
                }
                try identities.save(identity)
                preparation = nil
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Signing Failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            SwiftUI.Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(verbatim: errorMessage ?? "") }
    }

    @MainActor private func editApp() async {
        guard let ipa, !isSigning, canUseSigningMethod else { return }
        let identity = method == .importedCertificate ? identityID.flatMap { selected in identities.identities.first { $0.id == selected } } : nil
        isSigning = true
        result = nil
        defer { isSigning = false }
        do { preparation = try await SignIPAService.prepare(ipa, identity: identity, customization: customization) }
        catch { errorMessage = error.localizedDescription }
    }

    @MainActor private func sign() async {
        guard !isSigning, let ipa else { return }
        let identity = method == .importedCertificate ? identityID.flatMap { selected in identities.identities.first { $0.id == selected } } : nil
        // A removed selection must never silently switch to Apple Account signing.
        guard method == .appleAccount || identity != nil else {
            errorMessage = NSLocalizedString("The selected signing identity is no longer available.", comment: "")
            return
        }
        isSigning = true
        result = nil
        defer { isSigning = false }
        do {
            if let preparation { result = try await SignIPAService.sign(preparation) }
            else {
                let ready = try await SignIPAService.prepare(ipa, identity: identity, customization: customization)
                result = try await SignIPAService.sign(ready)
            }
            preparation = nil
        }
        catch { errorMessage = error.localizedDescription }
    }
}
