#if os(iOS)
import SwiftUI
import CoreData
import Combine
import SideSign

@MainActor
final class SelfProvisioning: ObservableObject {
    static let shared = SelfProvisioning()
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var progress = 0.0
    @Published private(set) var installing = false
    @Published private(set) var cancelling = false
    private var activeGroup: RefreshGroup?
    private var progressObservation: NSKeyValueObservation?

    func cancel() {
        guard busy, !installing, !cancelling else { return }
        cancelling = true
        message = "Cancelling. Waiting for current requests to finish."
        activeGroup?.cancel()
    }

    func signWithTunnel() async {
        guard !busy else { return }
        busy = true
        installing = false
        cancelling = false
        progress = 0
        message = "Checking App IDs, capabilities and profiles in your Apple Account. zLoader will then be signed and installed with all extensions."
        defer {
            progressObservation = nil
            activeGroup = nil
            busy = false
            installing = false
            cancelling = false
        }
        do {
            let team = try await AuthManager.shared.getAuthenticatedTeam()
            guard team.type.isPaid else {
                throw OperationError.invalidParameters("The internal tunnel requires an eligible paid developer team. You can keep using an external local VPN tunnel.")
            }
            guard let running = ALTApplication(fileURL: Bundle.Info.activeBundleURL),
                  running.provisioningProfile?.teamIdentifier == team.identifier else {
                throw OperationError.invalidParameters("For self-signing, select the team of the installed app. Switching teams changes the app identity and data containers.")
            }
            let context = DatabaseManager.shared.viewContext
            let installed = try await context.perform {
                let predicate = NSPredicate(format: "%K == %@", #keyPath(InstalledApp.resignedBundleIdentifier), running.bundleIdentifier)
                guard let app = InstalledApp.first(satisfying: predicate, in: context) else {
                    throw OperationError.invalidParameters("zLoader is not ready in the app database yet. Finish setup and try again in Connection settings.")
                }
                return app
            }
            try Task.checkCancellation()
            guard !cancelling else { throw CancellationError() }
            // Persist before self-replacement, which may terminate this process.
            // Do not select the internal transport until the new installation is verified.
            UserDefaults.standard.set(true, forKey: TunnelBootstrapPayload.requestKey)
            UserDefaults.standard.set(true, forKey: TunnelBootstrapPayload.pendingKey)
            UserDefaults.standard.set(false, forKey: "zLoader.useInternalVPN")
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let group = AppManager.shared.resign(installed, presentingViewController: UIApplication.shared.topViewController()) { result in
                    continuation.resume(with: result.map { _ in () })
                }
                activeGroup = group
                progressObservation = group.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] _, change in
                    let value = change.newValue ?? 0
                    Task { @MainActor in self?.progress = min(max(value, 0), 1) }
                }
                group.beginInstallationHandler = { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.busy else { return }
                        self.installing = true
                        self.message = "Signing complete. zLoader is being replaced. If installation waits for the running app to close, fully close zLoader in the app switcher and leave your external local VPN tunnel enabled. Reopen zLoader after installation to verify the new tunnel."
                    }
                }
            }
            message = "zLoader was reinstalled. Reopen the app to verify and configure the internal tunnel."
        } catch {
            UserDefaults.standard.set(false, forKey: TunnelBootstrapPayload.requestKey)
            UserDefaults.standard.set(false, forKey: TunnelBootstrapPayload.pendingKey)
            message = cancelling || error is CancellationError ? "Self-signing cancelled. You can continue using your external local VPN tunnel." : error.localizedDescription
        }
    }
}

struct SelfProvisioningView: View {
    var onReady: () -> Void = {}
    var automaticallyVerify: Bool = false
    @ObservedObject private var provisioning = SelfProvisioning.shared
    @State private var attempted = false
    @State private var configuring = false
    @State private var configured = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("zLoader requests the required capabilities and separate provisioning profiles for the app and its extensions from Apple. It then signs and reinstalls itself. Reopen the app afterwards. Your App ID and App Group stay the same. Once setup succeeds, device operations use the integrated tunnel instead of an external VPN.")
                .foregroundStyle(.secondary)
            if configured {
                Label("Internal Tunnel Is Reachable", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else if EmbeddedTunnel.shared.unavailableReason == nil {
                SwiftUI.Button(configuring ? "Connecting…" : "Use Internal Tunnel") {
                    Task { await configure() }
                }.buttonStyle(OnboardingPrimaryButtonStyle()).disabled(configuring)
            } else {
                SwiftUI.Button(provisioning.busy ? "Signing zLoader…" : "Use Internal Tunnel") {
                    Task { await provisioning.signWithTunnel() }
                }.buttonStyle(OnboardingPrimaryButtonStyle()).disabled(provisioning.busy)
                Text("If Apple does not authorize the capability, continue with your external tunnel and try signing again later.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if provisioning.busy {
                ProgressView(value: provisioning.progress)
                Text("\(Int(provisioning.progress * 100)) %").font(.caption).monospacedDigit()
                if !provisioning.installing {
                    SwiftUI.Button("Cancel Self-Signing", role: .cancel) { provisioning.cancel() }
                        .disabled(provisioning.cancelling)
                }
            } else if configuring { ProgressView() }
            if let text = provisioning.busy ? provisioning.message : (message ?? provisioning.message) {
                Text(text).font(.footnote).textSelection(.enabled)
            }
        }
        .onChange(of: provisioning.busy) { _, busy in
            if busy { message = nil }
        }
        .task {
            guard !attempted, !provisioning.busy else { return }
            attempted = true
            if automaticallyVerify && EmbeddedTunnel.shared.unavailableReason == nil {
                await configure()
            } else if EmbeddedTunnel.shared.unavailableReason != nil && UserDefaults.standard.bool(forKey: TunnelBootstrapPayload.pendingKey) {
                UserDefaults.standard.set(false, forKey: TunnelBootstrapPayload.pendingKey)
                UserDefaults.standard.set(false, forKey: TunnelBootstrapPayload.requestKey)
                message = "The previous setup was interrupted or the installation still lacks an authorized tunnel. Leave your external tunnel enabled and try self-signing again."
            }
        }
    }

    @MainActor private func configure() async {
        guard !configuring else { return }
        configuring = true
        defer { configuring = false }
        do {
            try await EmbeddedTunnel.shared.configure()
            UserDefaults.standard.set(true, forKey: "zLoader.useInternalVPN")
            // A successful preference save alone does not prove device reachability.
            _ = try await ZLoaderTransport.withLease { try await fetchUDID(forceLive: true) }
            configured = true
            UserDefaults.standard.set(false, forKey: TunnelBootstrapPayload.pendingKey)
            UserDefaults.standard.set(false, forKey: TunnelBootstrapPayload.requestKey)
            onReady()
        } catch {
            UserDefaults.standard.set(false, forKey: "zLoader.useInternalVPN")
            message = error.localizedDescription
        }
    }
}
#endif
