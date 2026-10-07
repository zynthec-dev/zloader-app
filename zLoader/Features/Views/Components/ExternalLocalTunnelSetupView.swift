#if os(iOS)
import SwiftUI
import Minimuxer

struct ExternalLocalTunnelSetupView: View {
    @ObservedObject private var connection = ConnectionConfig.shared
    @ObservedObject private var hooks = OperationShortcutHooks.shared
    var onReady: (Bool) -> Void = { _ in }
    var showsConnectionControls = true
    var isExternalSelected = true
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(OperationShortcutHooks.beforeKey) private var beforeShortcut = ""
    @AppStorage(OperationShortcutHooks.afterKey) private var afterShortcut = ""
    @State private var checking = false
    @State private var ready = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsConnectionControls {
                Text("Use a compatible external local VPN tunnel for on-device services. zLoader checks device reachability without opening or controlling a VPN app.")
                    .font(.footnote).foregroundStyle(.secondary)
                Label(ready ? "Connected" : "Not Connected", systemImage: ready ? "checkmark.circle.fill" : "network")
                    .foregroundStyle(ready ? Color.green : Color.secondary)
                Text(connection.tunnelPeerReachable ? (connection.tunnelPeerIp ?? connection.effectiveTunnelPeerIP) : connection.effectiveTunnelPeerIP)
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                if let message { Text(message).font(.footnote).textSelection(.enabled) }
                if let name = hooks.waitingName {
                    Text("Waiting for Shortcut: \(name)").font(.footnote)
                    SwiftUI.Button("Cancel Waiting Hook", role: .destructive) { hooks.cancelWaiting() }
                }
                if ready { Label("Device Endpoint Reachable", systemImage: "checkmark.shield.fill") }
            }
            DisclosureGroup("Run Shortcuts During Operations") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Before Installation / Refresh: Shortcut Name", text: $beforeShortcut)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("After Completion / Failure / Cancellation: Shortcut Name", text: $afterShortcut)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Leave a name empty to disable its hook. Your first shortcut can connect the external tunnel; the second can disconnect it or restore your preferred VPN. Use Set VPN in Shortcuts. zLoader waits for the callback, checks device connectivity, and calls the completion shortcut after the operation finishes. Batch refresh uses one start and completion. Hooks open Shortcuts and require zLoader in the foreground. Do not run a zLoader installation action inside a hook.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Shortcut input: JSON with event (before, succeeded, failed, cancelled) and bundleIdentifiers. Without a callback the operation waits until cancelled in zLoader. The completion hook is not guaranteed after process termination or while the device is locked.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            DisclosureGroup("Alternative: Use an Operation Shortcut") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recommended: Set VPN → connect your external tunnel → Install IPA with Result or Refresh All Apps with Result → Set VPN → disconnect the tunnel. Check the result afterwards. These actions wait for completion and return Succeeded, Failed or Cancelled so the next step can run.")
                    Text("Personal automation: App → zLoader → Is Opened → Run Immediately → Set VPN: connect your external tunnel. Another automation can disconnect when you leave. Is Closed also fires when switching apps and can interrupt a refresh. Use the operation shortcut sequence for installations.")
                    Text("Choose the VPN on this iPhone. Create personal automations in Shortcuts; zLoader does not install them automatically. Cancelling or terminating a shortcut can prevent its disconnect step.")
                    Link("Open Shortcuts", destination: URL(string: "shortcuts://")!)
                    Link("Apple Guide", destination: URL(string: "https://support.apple.com/de-de/guide/shortcuts/apdfbdbd7123/ios")!)
                }.font(.footnote).foregroundStyle(.secondary)
            }
        }
        .onReceive(connection.$tunnelPeerReachable.combineLatest(connection.$overrideTunnelPeerReachable)) { discovered, override in
            guard showsConnectionControls, isExternalSelected else { return }
            ready = connection.isEffectivePeerReachable(discovered: discovered, override: override)
            if ready { message = nil }
            onReady(ready)
        }
        .task { if showsConnectionControls && isExternalSelected { await checkConnection() } }
        .onChange(of: scenePhase) { _, phase in
            if showsConnectionControls && isExternalSelected && phase == .active {
                Task { await checkConnection() }
            }
        }
    }
    @MainActor private func checkConnection() async {
        guard isExternalSelected, !checking else { return }
        checking = true
        defer { checking = false }
        syncMinimuxerBackendFromUserDefaults()
        await bindConnectionConfig()
        await minimuxer.network.refreshEndpoint()
        ready = ConnectionConfig.shared.tunnelPeerActive == .yes
        message = ready ? nil : "The device service is not reachable at the tunnel IP. Enable a compatible external local tunnel. Pairing is configured in the next step."
        onReady(ready)
    }
}
#endif
