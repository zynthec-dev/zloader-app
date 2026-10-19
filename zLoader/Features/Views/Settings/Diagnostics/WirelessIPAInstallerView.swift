import SwiftUI
import SideSign

@MainActor
private final class WirelessIPAInstallerModel: ObservableObject {
    @Published var selected: CacheItem?
    @Published var status = LANIPAServer.Status()
    @Published var preparing = false
    @Published var certificateURL: URL?
    @Published var error: String?
    private var server: LANIPAServer?
    private var directory: URL?
    private var generation = UUID()
    private var authority: LANCertificate.Authority?
    private var oldIdleTimer = false
    private var ownsIdleTimer = false
    private var certificateName: String { "zLoader — " + UIDevice.current.name }

    func prepareCertificate() async {
        do {
            let name = certificateName
            let ca = try await Task.detached(priority: .userInitiated) {
                try LANCertificate.authority(name: name)
            }.value
            authority = ca
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("zLoader-LAN-Trust.mobileconfig")
            try LANCertificate.trustProfile(authority: ca, name: certificateName).write(to: url, options: .atomic)
            certificateURL = url
        } catch { self.error = error.localizedDescription }
    }
    func start() async {
        guard let selected, !preparing else { return }
        stop()
        let current = UUID(); generation = current
        preparing = true; error = nil
        defer { if generation == current { preparing = false } }
        do {
            guard let ip = LANIPAServer.wifiAddress() else {
                throw OperationError.invalidParameters(NSLocalizedString("Connect to Wi-Fi before starting the LAN server.", comment: ""))
            }
            if authority == nil { await prepareCertificate() }
            guard generation == current else { return }
            guard let authority else { return }
            let selectedURL = selected.url
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            directory = folder
            let result = try await Task.detached(priority: .userInitiated) { () throws -> (URL, String, String, String) in
                let fm = FileManager.default
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                let copy = folder.appendingPathComponent("app.ipa")
                try fm.copyItem(at: selectedURL, to: copy)
                let appURL = try fm.unzipAppBundle(at: copy, to: folder.appendingPathComponent("Inspection", isDirectory: true))
                defer { try? fm.removeItem(at: folder.appendingPathComponent("Inspection")) }
                guard let app = ALTApplication(fileURL: appURL) else { throw OperationError.invalidApp(reason: "Unreadable IPA") }
                for bundle in [app] + app.appExtensions {
                    guard let profile = bundle.provisioningProfile, profile.expirationDate > Date() else {
                        throw OperationError.invalidParameters(NSLocalizedString("The app and every extension need an unexpired Apple provisioning profile. Sign this IPA before sharing it.", comment: ""))
                    }
                    _ = try SigningEntitlements.prepare(application: bundle.entitlements, profile: profile.entitlements,
                        teamID: profile.teamIdentifier, bundleIdentifier: bundle.bundleIdentifier)
                }
                return (copy, app.bundleIdentifier, app.infoPlist["CFBundleVersion"] as? String ?? "1", app.name)
            }.value
            guard generation == current else { try? FileManager.default.removeItem(at: folder); return }
            let server = LANIPAServer { [weak self] update in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == current else { return }
                    self.status = update
                    if let message = update.error { self.stop(); self.error = message }
                }
            }
            self.server = server
            oldIdleTimer = UIApplication.shared.isIdleTimerDisabled; ownsIdleTimer = true
            UIApplication.shared.isIdleTimerDisabled = true
            server.start(ipa: result.0, ip: ip, name: result.3, bundleID: result.1, version: result.2, authority: authority)
        } catch {
            if generation == current { self.error = error.localizedDescription; stop() }
        }
    }
    func stop() {
        generation = UUID(); preparing = false
        server?.stop(); server = nil; status = LANIPAServer.Status()
        if ownsIdleTimer { UIApplication.shared.isIdleTimerDisabled = oldIdleTimer; ownsIdleTimer = false }
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
    }
}

struct WirelessIPAInstallerView: View {
    @StateObject private var model = WirelessIPAInstallerModel()
    @StateObject private var library = CacheViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selecting = false

    var body: some View {
        List {
            Section {
                SwiftUI.Button { selecting = true } label: {
                    if let item = model.selected { IPASelectionRow(item: item) }
                    else { Label("Choose Signed IPA", systemImage: "doc.zipper") }
                }.disabled(model.preparing || model.status.url != nil)
                if let item = model.selected { Text(item.sizeString).foregroundStyle(.secondary) }
            } header: { Text("Signed IPA") }.zLoaderSettingsRows()
            Section {
                if let url = model.certificateURL {
                    ShareLink(item: url) { Label("Share HTTPS Certificate", systemImage: "lock.shield") }
                }
                Text("Install this certificate profile on the receiving device, then enable full trust in Settings → General → About → Certificate Trust Settings. Share only with devices you trust; remove the profile when you no longer need it.")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text("HTTPS Certificate") }.zLoaderSettingsRows()
            Section {
                if let url = model.status.url {
                    Label("Server Running", systemImage: "wifi").foregroundStyle(.green)
                    Text(url.absoluteString).font(.footnote).textSelection(.enabled)
                    ShareLink(item: url) { Label("Share Installation Link", systemImage: "square.and.arrow.up") }
                    ProgressView(value: model.status.progress)
                    if model.status.complete {
                        Label("Transfer Complete", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("The IPA was transferred. Only the receiving device can confirm installation.").font(.footnote).foregroundStyle(.secondary)
                    }
                    SwiftUI.Button("Stop Server", role: .destructive) { model.stop() }
                } else {
                    SwiftUI.Button { Task { await model.start() } } label: {
                        HStack {
                            if model.preparing { ProgressView() }
                            Text(LocalizedStringKey(model.preparing ? "Preparing Server…" : "Start Server"))
                        }
                    }.disabled(model.selected == nil || model.preparing)
                }
                Text("Both devices must be on the same Wi-Fi network. Keep this screen open. The IPA must already authorize the receiving device and every required capability; HTTPS does not change its signature.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let error = model.error { Text(error).foregroundStyle(.red) }
            } header: { Text("Local Server") }.zLoaderSettingsRows()
        }
        .navigationTitle("Wireless IPA Installer")
        .zLoaderSettingsPage()
        .task { await model.prepareCertificate() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { model.stop() } }
        .sheet(isPresented: $selecting) {
            NavigationStack {
                List {
                    if library.isLoading { ProgressView() }
                    ForEach(library.resignedApps) { item in
                        SwiftUI.Button { model.selected = item; selecting = false } label: {
                            IPASelectionRow(item: item)
                        }
                    }
                    if !library.isLoading && library.resignedApps.isEmpty { Text("No signed IPAs saved yet.") }
                }
                .navigationTitle("IPA Library")
                .zLoaderSettingsPage()
                .task { await library.loadCacheItems(includeInternalApps: false) }
                .refreshable { await library.loadCacheItems(includeInternalApps: false) }
                .onDisappear { library.cancelLoading() }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { SwiftUI.Button("Done") { selecting = false } } }
            }
        }
    }
}

private struct IPASelectionRow: View {
    let item: CacheItem

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = item.image { Image(uiImage: image).resizable().scaledToFit() }
                else { Image(systemName: "app.dashed").resizable().scaledToFit().padding(6).foregroundStyle(.secondary) }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: item.name).foregroundStyle(.primary)
                Text(item.sizeString).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
