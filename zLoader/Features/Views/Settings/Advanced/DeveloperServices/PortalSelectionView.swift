import SwiftUI
import SideSign

// Every batch uses the same verified portal mutations as the detail screens.
// Successes are retained if another item fails; failed items stay in the list.
enum PortalResourceKind: String, CaseIterable, Identifiable {
    case appIDs, appGroups, profiles, devices, certificates
    var id: String { rawValue }
    var title: String {
        switch self {
        case .appIDs: "App IDs"
        case .appGroups: "App Groups"
        case .profiles: "Provisioning Profiles"
        case .devices: "Registered Devices"
        case .certificates: "Certificates"
        }
    }
}

struct PortalSelectionView: View {
    @ObservedObject var viewModel: DeveloperServicesViewModel
    let kind: PortalResourceKind
    @State private var selected: Set<String> = []
    @State private var editMode: EditMode = .active
    @State private var isProcessing = false
    @State private var confirmsMutation = false
    @State private var resultMessage: String?

    private struct Item: Identifiable {
        let id: String
        let name: String
        let detail: String
    }

    private var items: [Item] {
        switch kind {
        case .appIDs: viewModel.appIDs.map { Item(id: $0.identifier, name: $0.name, detail: $0.bundleIdentifier) }
        case .appGroups: viewModel.appGroups.map { Item(id: $0.identifier, name: $0.name, detail: $0.groupIdentifier) }
        case .profiles: viewModel.profiles.map { Item(id: $0.uuid.uuidString, name: $0.name, detail: $0.bundleIdentifier ?? "") }
        case .devices: viewModel.devices.map { Item(id: $0.identifier, name: $0.name, detail: $0.identifier) }
        case .certificates: viewModel.certificates.map { Item(id: $0.serialNumber, name: $0.name, detail: $0.serialNumber) }
        }
    }

    var body: some View {
        List(selection: $selected) {
            Section {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: item.name).font(.body)
                        Text(verbatim: item.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(item.id)
                }
            } footer: {
                Group {
                    Text("Changes are applied to the Apple Developer Portal. An item is removed here only after Apple confirms it is no longer present.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
        }
        .onChange(of: items.map(\.id)) { _, available in
            selected.formIntersection(Set(available))
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(LocalizedStringKey(kind.title))
        .labelStyle(.titleOnly)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SwiftUI.Button(selected.count == items.count ? "Deselect All" : "Select All") {
                    selected = selected.count == items.count ? [] : Set(items.map(\.id))
                }.disabled(isProcessing)
            }
            ToolbarItem(placement: .bottomBar) {
                SwiftUI.Button(role: .destructive) { confirmsMutation = true } label: {
                    Label(LocalizedStringKey(kind == .certificates ? "Revoke Selected" : "Delete Selected"), systemImage: "trash")
                }
                .disabled(selected.isEmpty || isProcessing)
            }
        }
        .disabled(isProcessing)
        .overlay { if isProcessing { ProgressView("Updating Developer Portal…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
        .confirmationDialog("Apply Changes to Apple Developer Portal?", isPresented: $confirmsMutation, titleVisibility: .visible) {
            SwiftUI.Button(kind == .certificates ? "Revoke Selected" : "Delete Selected", role: .destructive) {
                Task { await applySelection() }
            }
        } message: {
            Text("This changes the selected resources on Apple's servers. Certificates and dependent installations may become unusable. This cannot be undone.")
        }
        .alert("Portal Result", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            SwiftUI.Button("OK", role: .cancel) { resultMessage = nil }
        } message: { Text(verbatim: resultMessage ?? "") }
    }

    @MainActor private func applySelection() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        let targets = items.filter { selected.contains($0.id) }
        var completed = 0
        var failures: [String] = []
        for item in targets {
            viewModel.errorMessage = nil
            let success: Bool
            switch kind {
            case .appIDs:
                if let resource = viewModel.appIDs.first(where: { $0.identifier == item.id }) { success = await viewModel.deleteAppID(resource) } else { success = false }
            case .appGroups:
                if let resource = viewModel.appGroups.first(where: { $0.identifier == item.id }) { success = await viewModel.deleteAppGroup(resource) } else { success = false }
            case .profiles:
                if let resource = viewModel.profiles.first(where: { $0.uuid.uuidString == item.id }) { success = await viewModel.deleteProfile(resource) } else { success = false }
            case .devices:
                if let resource = viewModel.devices.first(where: { $0.identifier == item.id }) { success = await viewModel.deleteDevice(resource) } else { success = false }
            case .certificates:
                if let resource = viewModel.certificates.first(where: { $0.serialNumber == item.id }) { success = await viewModel.revokeCertificate(resource) } else { success = false }
            }
            if success { completed += 1; selected.remove(item.id) }
            else { failures.append(item.name + ": " + (viewModel.errorMessage ?? NSLocalizedString("The portal change was not confirmed.", comment: ""))) }
        }
        resultMessage = String(format: NSLocalizedString("%d changes confirmed. %d failed.", comment: ""), completed, failures.count)
            + (failures.isEmpty ? "" : "\n\n" + failures.joined(separator: "\n"))
    }
}
