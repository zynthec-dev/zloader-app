import SwiftUI
import AppIntents
import IntentsUI

struct ShortcutsSettingsView: View {
    @State private var addingRefresh = false
    @AppStorage("zLoader.useInternalVPN") private var useInternal = false

    var body: some View {
        Form {
            Section {
                SwiftUI.Button { addingRefresh = true } label: {
                    SettingsEntryLabel(title: "Add Refresh All Apps to Siri")
                }
                if #available(iOS 17, tvOS 17, *) {
                    ShortcutsLink()
                }
            } header: {
                Text("Add Shortcuts")
            } footer: {
                Group {
                    Text("Open zLoader in Shortcuts to add Install IPA, Refresh All Apps or Enable JIT to your own shortcuts.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
            Section {
                Text("Create a personal automation in Shortcuts: App → Is Opened → Run Immediately → Enable JIT. Select the same app in the JIT action. The integrated tunnel connects for activation and disconnects afterwards; JIT remains enabled until that app process ends. External tunnels must be connected separately. iOS decides whether background execution is available.")
                    .foregroundStyle(.secondary)
            } header: { Text("Automatic JIT") }
            .listRowBackground(ZLoaderGlassBackground())
            #if os(iOS)
            Section {
                ExternalLocalTunnelSetupView(showsConnectionControls: false, isExternalSelected: !useInternal)
                    .disabled(useInternal).opacity(useInternal ? 0.45 : 1)
            } header: {
                Text("External Tunnel Shortcuts")
            } footer: {
                Group {
                    Text(useInternal ? "External tunnel hooks are disabled while the internal tunnel is selected." : "Choose your VPN in Shortcuts using Set VPN. Personal automations must be created in Shortcuts on this device.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
            #endif
        }
        .navigationTitle("Shortcuts")
        .zLoaderSettingsPage()
        .labelStyle(.titleOnly)
        #if os(iOS)
        .sheet(isPresented: $addingRefresh) {
            RefreshShortcutAdder()
        }
        #endif
    }
}

#if os(iOS)
private struct RefreshShortcutAdder: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator { dismiss() } }

    func makeUIViewController(context: Context) -> UIViewController {
        guard let shortcut = INShortcut(intent: INInteraction.refreshAllApps().intent) else {
            return UIViewController()
        }
        let controller = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    final class Coordinator: NSObject, INUIAddVoiceShortcutViewControllerDelegate {
        let close: () -> Void
        init(close: @escaping () -> Void) { self.close = close }
        func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) { close() }
        func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) { close() }
    }
}
#endif
