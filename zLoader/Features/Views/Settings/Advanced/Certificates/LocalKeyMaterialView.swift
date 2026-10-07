import SwiftUI
import UniformTypeIdentifiers

private struct KeyMaterialDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct LocalKeyMaterialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [LocalKeyMaterialStore.Item] = []
    @State private var creating = false
    @State private var busy = false
    @State private var importing = false
    @State private var importPrivate = true
    @State private var exportDocument: KeyMaterialDocument?
    @State private var exporting = false
    @State private var exportName = "SigningRequest.csr"
    @State private var privateExport: LocalKeyMaterialStore.Item?
    @State private var deleting: LocalKeyMaterialStore.Item?
    @State private var renaming: LocalKeyMaterialStore.Item?
    @State private var renameText = ""
    @State private var message: String?
    @State private var commonName = ""
    @State private var email = ""
    @State private var organization = ""

    var body: some View {
        List {
            Section {
                SwiftUI.Button { creating = true } label: {
                    SettingsEntryLabel(title: "Create Local Signing Request…", systemImage: "doc.badge.plus")
                }
                Menu {
                    SwiftUI.Button("Private RSA Key (.pem/.der)") { importPrivate = true; importing = true }
                    SwiftUI.Button("Public RSA Key (.pem/.der)") { importPrivate = false; importing = true }
                } label: {
                    SettingsEntryLabel(title: "Import Key…", systemImage: "key.horizontal")
                }
            } footer: {
                Group {
                    Text("Requests are created locally without an Apple login. Private keys remain in this app's protected keychain. Import Apple's returned certificate in the certificate manager to match it to its key.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
            Section("Keys and Signing Requests") {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(item.name, systemImage: item.privateKey == nil ? "key" : "key.fill").font(.headline)
                        Text(item.privateKey == nil ? "Public key" : "Private + public key").foregroundStyle(.secondary)
                        Text(item.created, style: .date).font(.caption)
                        Text("SHA-256: " + item.fingerprint).font(.caption.monospaced()).textSelection(.enabled)
                        Menu("Manage") {
                            if let request = item.request {
                                SwiftUI.Button("Save Signing Request…") { export(request, name: item.name + ".csr") }
                            }
                            SwiftUI.Button("Save Public Key…") { export(item.publicKey, name: item.name + "_public.pem") }
                            if item.privateKey != nil {
                                SwiftUI.Button("Save Private Key…") { privateExport = item }
                            }
                            SwiftUI.Button("Rename…") { renameText = item.name; renaming = item }
                            SwiftUI.Button("Delete Local Key", role: .destructive) { deleting = item }
                        }
                    }
                    .padding(.vertical, 4)
                }
                if items.isEmpty { Text("No local keys or requests.").foregroundStyle(.secondary) }
            }.listRowBackground(ZLoaderGlassBackground())
            if let message { Section { Text(message).textSelection(.enabled) }.listRowBackground(ZLoaderGlassBackground()) }
        }
        .navigationTitle("Keys & Signing Requests")
        .labelStyle(.titleAndIcon)
        .environment(\.settingsEntryIconsVisible, true)
        .toolbar { ToolbarItem(placement: .confirmationAction) { SwiftUI.Button("Done") { dismiss() } } }
        .task { reload() }
        .sheet(isPresented: $creating) {
            NavigationStack {
                Form {
                    Section("Certificate Request") {
                        TextField("Common Name", text: $commonName)
                        TextField("Email Address (optional)", text: $email).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("Organization (optional)", text: $organization)
                    }.listRowBackground(ZLoaderGlassBackground())
                    Section {
                        Text("RSA 2048 • SHA-256. A key pair is generated and retained locally. Save the CSR to Files and submit it to Apple; the CSR contains no private key.")
                        if busy { ProgressView() }
                    }.listRowBackground(ZLoaderGlassBackground())
                }
                .navigationTitle("Local Signing Request")
        .labelStyle(.titleAndIcon)
        .environment(\.settingsEntryIconsVisible, true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { SwiftUI.Button("Cancel") { creating = false }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) {
                        SwiftUI.Button("Create") {
                            let name = commonName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                            let org = organization.trimmingCharacters(in: .whitespacesAndNewlines)
                            busy = true
                            Task {
                                defer { busy = false }
                                do {
                                    let item = try await Task.detached { try LocalKeyMaterialStore.createRequest(name: name, email: mail, organization: org) }.value
                                    reload(); creating = false
                                    message = "Request and key pair saved locally. Choose Save Signing Request to write the CSR to Files."
                                    commonName = ""; email = ""; organization = ""
                                    _ = item
                                } catch { message = error.localizedDescription; creating = false }
                            }
                        }.disabled(busy || commonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
                defer { url.stopAccessingSecurityScopedResource() }
                try LocalKeyMaterialStore.importKey(Data(contentsOf: url), name: url.deletingPathExtension().lastPathComponent, isPrivate: importPrivate)
                reload(); message = "Key imported and validated."
            } catch { message = error.localizedDescription }
        }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .data, defaultFilename: exportName) { result in
            switch result {
            case .success: message = "File saved."
            case .failure(let error): message = error.localizedDescription
            }
            exportDocument = nil
        }
        .alert("Export Private Key", isPresented: Binding(get: { privateExport != nil }, set: { if !$0 { privateExport = nil } })) {
            SwiftUI.Button("Save Unencrypted Key", role: .destructive) {
                if let item = privateExport, let key = item.privateKey { export(key, name: item.name + "_private.pem") }
                privateExport = nil
            }
            SwiftUI.Button("Cancel", role: .cancel) { privateExport = nil }
        } message: { Text("This PEM export is unencrypted. Anyone with the file can use the key. Use the certificate manager's password-protected P12 export once the matching certificate is imported.") }
        .alert("Delete Local Key?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            SwiftUI.Button("Delete", role: .destructive) {
                if let item = deleting { do { try LocalKeyMaterialStore.delete(item); reload() } catch { message = error.localizedDescription } }
                deleting = nil
            }
            SwiftUI.Button("Cancel", role: .cancel) { deleting = nil }
        } message: { Text("This deletes this stored key and CSR. It does not revoke an Apple certificate or remove copies already attached to signing certificates.") }
        .alert("Rename Key", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            SwiftUI.Button("Save") {
                if var item = renaming { item.name = renameText; do { try LocalKeyMaterialStore.save(item); reload() } catch { message = error.localizedDescription } }
                renaming = nil
            }
            SwiftUI.Button("Cancel", role: .cancel) { renaming = nil }
        }
    }
    private func reload() { do { items = try LocalKeyMaterialStore.list() } catch { message = error.localizedDescription } }
    private func export(_ data: Data, name: String) {
        exportName = name.replacingOccurrences(of: "/", with: "_")
        exportDocument = KeyMaterialDocument(data: data); exporting = true
    }
}
