import SwiftUI
import Minimuxer

/// Shared export controls for onboarding and Connection Settings.
struct WireGuardSetupView: View {
    @AppStorage(WireGuardLocalTunnel.selectionKey) private var useWireGuard = false
    @State private var exporting = false
    @State private var exportedFile: URL?
    @State private var showingExport = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use WireGuard", isOn: $useWireGuard)
                .onChange(of: useWireGuard) { _, selected in
                    Task {
                        do {
                            if selected { try await WireGuardLocalTunnel.shared.prepare() }
                            else { try await WireGuardLocalTunnel.shared.stop() }
                            await minimuxer.network.refreshEndpoint()
                        } catch { errorMessage = error.localizedDescription }
                    }
                }
            Text("Import the exported configuration in WireGuard, enable it, then return to zLoader. Keep WireGuard enabled during device operations. Other compatible local VPN apps can also be used.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("WireGuard requires compatible pairing. On iOS 26.4 or later, use Self-Pairing instead of a legacy Lockdown pairing file.")
                .font(.footnote).foregroundStyle(.secondary)
            SwiftUI.Button {
                exporting = true
                errorMessage = nil
                Task {
                    do {
                        exportedFile = try await WireGuardLocalTunnel.shared.exportConfiguration()
                        useWireGuard = true
                        showingExport = true
                    } catch { errorMessage = error.localizedDescription }
                    exporting = false
                }
            } label: {
                HStack {
                    Text("Export WireGuard Configuration")
                    Spacer()
                    if exporting { ProgressView() } else { Image(systemName: "square.and.arrow.up") }
                }
            }.disabled(exporting)
            if let errorMessage { Text(verbatim: errorMessage).font(.footnote).foregroundStyle(.secondary) }
        }
        .sheet(isPresented: $showingExport) {
            if let exportedFile { ActivityViewController(items: [exportedFile]) }
        }
    }
}
