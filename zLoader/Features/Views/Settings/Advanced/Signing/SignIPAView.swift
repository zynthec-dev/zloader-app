import SwiftUI
import UniformTypeIdentifiers

struct SignIPAView: View {
    var onInstall: ((URL) -> Void)? = nil
    @ObservedObject private var identities = SigningIdentityStore.shared
    @State private var identityID: UUID?
    @State private var ipa: URL?
    @State private var importingIPA = false
    @State private var importingProfiles = false
    @State private var isSigning = false
    @State private var result: URL?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("IPA") {
                SwiftUI.Button(ipa?.lastPathComponent ?? NSLocalizedString("Choose IPA", comment: "")) { importingIPA = true }
            }.listRowBackground(ZLoaderGlassBackground())
            Section("Sign With") {
                Picker("Signing Method", selection: $identityID) {
                    Text("Apple Account").tag(nil as UUID?)
                    ForEach(identities.identities) { identity in
                        Text(verbatim: identity.name).tag(Optional(identity.id))
                    }
                }
                NavigationLink("Signing Identities") { SigningIdentitiesView() }
                if identityID != nil {
                    SwiftUI.Button("Import Additional Profiles") { importingProfiles = true }
                }
            }.listRowBackground(ZLoaderGlassBackground())
            Section {
                SwiftUI.Button("Sign App") { Task { await sign() } }
                    .disabled(ipa == nil || isSigning)
                if isSigning { ProgressView("Signing…") }
                if let result {
                    ShareLink("Share Signed IPA", item: result)
                    NavigationLink("IPA Library") { CacheManagementView(signedIPAsOnly: true, onInstall: onInstall) }
                }
            } footer: {
                Group {
                    Text("Signing without installation always saves the IPA in Signed IPAs. The receiving device must be authorized by every embedded profile. A wildcard profile does not grant additional capabilities.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
        }
        .navigationTitle("Sign App")
        .labelStyle(.titleOnly)
        .disabled(isSigning)
        .fileImporter(isPresented: $importingIPA, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]) { selection in
            do { ipa = try selection.get(); result = nil } catch { errorMessage = error.localizedDescription }
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
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Signing Failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            SwiftUI.Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(verbatim: errorMessage ?? "") }
    }

    @MainActor private func sign() async {
        guard !isSigning, let ipa else { return }
        let identity = identityID.flatMap { selected in identities.identities.first { $0.id == selected } }
        // A removed selection must never silently switch to Apple Account signing.
        guard identityID == nil || identity != nil else {
            errorMessage = NSLocalizedString("The selected signing identity is no longer available.", comment: "")
            return
        }
        isSigning = true
        result = nil
        defer { isSigning = false }
        do { result = try await SignIPAService.sign(ipa, identity: identity) }
        catch { errorMessage = error.localizedDescription }
    }
}
