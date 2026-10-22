import SwiftUI

struct LCVirtualDeviceSettingsView: View {
    @AppStorage("ZLoaderUseVirtualDevice", store: LCUtils.appGroupUserDefault) private var useVirtual = false
    @State private var identity = LCVirtualDeviceIdentity.generate()
    @State private var confirmRegeneration = false

    var body: some View {
        Form {
            Section {
                Picker("Geräteidentität", selection: $useVirtual) {
                    Text("Host-Gerät verwenden").tag(false)
                    Text("Virtuelle Geräteidentität verwenden").tag(true)
                }.accessibilityIdentifier("container-device-identity-mode")
            } footer: {
                Text("Die Auswahl gilt für alle Container. Änderungen werden beim nächsten Start einer Container-App übernommen.")
            }
            Section {
                LabeledContent("Modell", value: identity.modelName)
                LabeledContent("Modellkennung", value: identity.hardwareIdentifier)
                LabeledContent("Gerätename", value: identity.deviceName)
                LabeledContent("Synthetische Seriennummer", value: identity.serialNumber)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kennung für Apps (IDFV)").font(.subheadline)
                    Text(identity.vendorIdentifier.uuidString).font(.caption.monospaced()).textSelection(.enabled)
                }
                Button("Virtuelle Identität neu erstellen") { confirmRegeneration = true }
                    .accessibilityIdentifier("container-regenerate-device-identity")
            } header: {
                Text("Gemeinsame virtuelle Identität")
            } footer: {
                Text("Apps erhalten geänderte Angaben über unterstützte Geräteabfragen. Hardware, Apple-Profile, Berechtigungen, Apple-Anmeldung und Gerätebestätigungen bleiben an das echte Gerät gebunden. Eine App kann weitere Prüfungen verwenden.")
            }
        }
        .navigationTitle("Geräteidentität")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let stored = LCUtils.appGroupUserDefault.dictionary(forKey: "ZLoaderVirtualDeviceIdentity"),
               let saved = LCVirtualDeviceIdentity(dictionary: stored) { identity = saved }
            else { save() }
        }
        .confirmationDialog("Gemeinsame virtuelle Identität ersetzen?", isPresented: $confirmRegeneration, titleVisibility: .visible) {
            Button("Neu erstellen", role: .destructive) { identity = .generate(); save() }
        } message: { Text("Alle Container verwenden beim nächsten Start dieselben neuen Kennungen. Ihre App-Daten bleiben erhalten.") }
    }
    private func save() { LCUtils.appGroupUserDefault.set(identity.dictionary, forKey: "ZLoaderVirtualDeviceIdentity") }
}
