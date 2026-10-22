import SwiftUI

struct IPAInstallDestinationView: View {
    let filename: String
    let checkDeviceAvailability: () async -> Bool
    @State private var checkingAppIDs = true
    @State private var appIDLimitReached = false
    let installOnDevice: () -> Void
    let installInContainer: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(filename).font(.headline).lineLimit(3)
                }.zLoaderSettingsRows()
                Section {
                    SwiftUI.Button(action: installOnDevice) {
                        option("Auf dem Gerät installieren", icon: "iphone", explanation:
                            "Eigenständige App mit eigenem Homescreen-Symbol. Benötigt eine gültige Signieridentität und passende Apple-Profile; unterstützt die dafür freigegebenen Systemfunktionen.")
                    }
                    .disabled(checkingAppIDs || appIDLimitReached)
                    .accessibilityIdentifier("install-destination-device")
                    if checkingAppIDs {
                        ProgressView("App-IDs werden geprüft …")
                    } else if appIDLimitReached {
                        Text("Keine App-IDs mehr verfügbar (0 von 10). Mit diesem kostenlosen Apple-Account kannst du die IPA weiterhin als Container installieren.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("install-destination-app-id-limit")
                    }
                    SwiftUI.Button(action: installInContainer) {
                        option("Als Container installieren", icon: "shippingbox", explanation:
                            "Läuft innerhalb von zLoader mit eigenen App-Daten. Mehrere Datencontainer, Tweaks und Homescreen-Verknüpfungen sind möglich. Teilt Berechtigungen mit zLoader; keine eigenen Push-Mitteilungen oder App-Erweiterungen. Die Laufzeit benötigt eine geeignete Signierung oder unterstütztes JIT.")
                    }.accessibilityIdentifier("install-destination-container")
                }.zLoaderSettingsRows()
            }
            .task {
                appIDLimitReached = await checkDeviceAvailability()
                checkingAppIDs = false
            }
            .navigationTitle("Installation wählen")
            .navigationBarTitleDisplayMode(.inline)
            .zLoaderSettingsPage()
            .toolbar { ToolbarItem(placement: .cancellationAction) { SwiftUI.Button("Abbrechen", action: cancel) } }
        }
    }

    private func option(_ title: String, icon: String, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            Text(explanation).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
    }
}
