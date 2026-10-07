import SwiftUI
import SideSign
import UniformTypeIdentifiers

struct SigningIdentitiesView: View {
    @ObservedObject private var store = SigningIdentityStore.shared
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(store.identities) { identity in
                    NavigationLink { SigningIdentityEditor(identity: identity) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: identity.name).font(.body)
                            Text("\(identity.profileIDs.count) profiles").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        SwiftUI.Button("Remove", role: .destructive) {
                            do { try store.remove(identity) } catch { errorMessage = error.localizedDescription }
                        }
                    }
                }
                NavigationLink("Add Signing Identity") { SigningIdentityEditor() }
            } footer: {
                Group {
                    Text("Import a PKCS#12 certificate with its private key and the Apple-signed profiles for the app and its extensions. Removing an identity here does not revoke anything in your Developer Account.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
        }
        .navigationTitle("Signing Identities")
        .labelStyle(.titleOnly)
        .alert("Signing Identity", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            SwiftUI.Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(verbatim: errorMessage ?? "") }
    }
}

private struct SigningIdentityEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ImportedSigningIdentity
    @State private var certificates: [ALTCertificate] = CertificateManager.shared.getAllLocalCertificates()
    @State private var profiles: [ALTProvisioningProfile] = ProfileManager.shared.getAllLocalProfiles()
    @State private var importsCertificate = false
    @State private var showsImporter = false
    @State private var pendingCertificate: URL?
    @State private var password = ""
    @State private var showsPassword = false
    @State private var errorMessage: String?

    init(identity: ImportedSigningIdentity? = nil) {
        _draft = State(initialValue: identity ?? ImportedSigningIdentity(name: "", certificateSerial: "", profileIDs: []))
    }

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $draft.name)
                Picker("Certificate", selection: $draft.certificateSerial) {
                    Text("Choose Certificate").tag("")
                    ForEach(certificates, id: \.serialNumber) { certificate in
                        Text(verbatim: certificate.name + " · " + certificate.serialNumber).tag(certificate.serialNumber)
                    }
                }
                SwiftUI.Button("Import Certificate and Private Key") {
                    importsCertificate = true
                    showsImporter = true
                }
            }.listRowBackground(ZLoaderGlassBackground())
            Section {
                ForEach(profiles, id: \.uuid) { profile in
                    Toggle(isOn: Binding(get: { draft.profileIDs.contains(profile.uuid) }, set: { enabled in
                        draft.profileIDs.removeAll { $0 == profile.uuid }
                        if enabled { draft.profileIDs.append(profile.uuid) }
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: profile.name).font(.body)
                            Text(verbatim: profile.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                SwiftUI.Button("Import Provisioning Profiles") {
                    importsCertificate = false
                    showsImporter = true
                }
            } header: { Text("Provisioning Profiles") } footer: {
                Group {
                    Text("Each app and extension needs a matching profile. A wildcard profile cannot grant capabilities that Apple did not authorize.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
        }
        .navigationTitle("Signing Identity")
        .labelStyle(.titleOnly)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                SwiftUI.Button("Save") {
                    do { try SigningIdentityStore.shared.save(draft); dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }.disabled(draft.name.isEmpty || draft.certificateSerial.isEmpty || draft.profileIDs.isEmpty)
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.data], allowsMultipleSelection: !importsCertificate) { result in
            do {
                let urls = try result.get()
                if importsCertificate {
                    pendingCertificate = urls.first
                    password = ""
                    showsPassword = pendingCertificate != nil
                } else {
                    for url in urls {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let profile = try ProfileManager.shared.importProfile(from: url)
                        if !draft.profileIDs.contains(profile.uuid) { draft.profileIDs.append(profile.uuid) }
                    }
                    profiles = ProfileManager.shared.getAllLocalProfiles()
                }
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Certificate Password", isPresented: $showsPassword) {
            SecureField("Password", text: $password)
            SwiftUI.Button("Import") { importCertificate() }
            SwiftUI.Button("Cancel", role: .cancel) { password = ""; pendingCertificate = nil }
        } message: { Text("Enter the password used when exporting the .p12 file from Keychain Access.") }
        .alert("Signing Identity", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            SwiftUI.Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(verbatim: errorMessage ?? "") }
    }

    private func importCertificate() {
        guard let url = pendingCertificate else { return }
        defer { password = ""; pendingCertificate = nil }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let certificate = try CertificateManager.parse(Data(contentsOf: url), password: password.isEmpty ? nil : password)
            guard let data = certificate.data else { throw PortablePKCS12.Failure.invalidKey }
            try PortablePKCS12.validate(certificate: data, key: certificate.privateKey)
            CertificateManager.shared.saveCertificate(certificate)
            guard CertificateManager.shared.getLocalCertificate(serialNumber: certificate.serialNumber) != nil else {
                throw OperationError.invalidParameters(NSLocalizedString("The certificate could not be saved securely.", comment: ""))
            }
            certificates = CertificateManager.shared.getAllLocalCertificates()
            draft.certificateSerial = certificate.serialNumber
        } catch { errorMessage = error.localizedDescription }
    }
}
