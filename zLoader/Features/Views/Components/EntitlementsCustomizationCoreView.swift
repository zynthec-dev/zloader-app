// Copyright © 2026 SideStore. All rights reserved.
// zLoader native entitlement editor; original authors remain credited.
import SwiftUI
import UIKit
import SideSign

public enum EntitlementsCustomizationStyle { case sheet, dialog }

public struct EntitlementsCustomizationCoreView: View {
    public let style: EntitlementsCustomizationStyle
    @StateObject private var viewModel: EntitlementsCustomizationViewModel
    @State private var arrayDrafts: [UUID: String] = [:]

    public init(style: EntitlementsCustomizationStyle, targets: [EntitlementsTarget], teamType: ALTTeamType,
                onProceed: @escaping ([String: [String: any Sendable]]) -> Void, onCancel: @escaping () -> Void) {
        self.style = style
        _viewModel = StateObject(wrappedValue: EntitlementsCustomizationViewModel(
            targets: targets, teamType: teamType, onProceed: onProceed, onCancel: onCancel))
    }

    public init(style: EntitlementsCustomizationStyle, initialEntitlements: [String: any Sendable], bundleID: String,
                teamType: ALTTeamType, onProceed: @escaping ([String: any Sendable]) -> Void, onCancel: @escaping () -> Void) {
        self.style = style
        _viewModel = StateObject(wrappedValue: EntitlementsCustomizationViewModel(
            initialEntitlements: initialEntitlements, bundleID: bundleID, teamType: teamType,
            onProceed: onProceed, onCancel: onCancel))
    }

    public var body: some View {
        Group {
                if style == .sheet {
                    editor
                } else {
                    ZStack {
                        Color.black.opacity(0.45).ignoresSafeArea()
                        editor.frame(maxWidth: 600, maxHeight: 720)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .padding()
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingAddCustomSheet) { customEditor }
        }
        private var editor: some View {
            NavigationStack {
                List {
                    Section {
                        if viewModel.targets.count > 1 {
                            Picker("App / Extension", selection: Binding(
                                get: { viewModel.selectedTargetID },
                                set: { viewModel.selectTarget(id: $0) }
                            )) {
                                ForEach(viewModel.targets) { Text($0.name).tag($0.id) }
                            }
                        }
                        Text(viewModel.bundleID).font(.caption).textSelection(.enabled)
                            .foregroundStyle(.secondary)
                        LabeledContent("Account", value: viewModel.teamType.displayName)
                    } footer: {
                    Group {
                        Text("Permissions are requested separately for the app and each extension. Apple must authorize them in each profile.")
                }
            }.listRowBackground(ZLoaderGlassBackground())
                Section("Entitlements (\(viewModel.filteredActiveEntries.count))") {
                    ForEach(viewModel.filteredActiveEntries) { entry in
                        entitlementRow(entry)
                    }
                    SwiftUI.Button {
                        viewModel.resetCustomKeyFields()
                    } label: { Label("Eigenes Entitlement", systemImage: "plus") }
                }.listRowBackground(ZLoaderGlassBackground())
                Section("Available Capabilities") {
                    ForEach(viewModel.availableCatalogEntries) { entitlement in
                        SwiftUI.Button {
                            viewModel.addKnownEntitlement(entitlement)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entitlement.displayName).foregroundStyle(.primary)
                                    Text(entitlement.rawValue).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }.listRowBackground(ZLoaderGlassBackground())
            }
            .listStyle(.insetGrouped)
            .searchable(text: $viewModel.searchQuery, prompt: "Entitlements suchen")
            .navigationTitle("Entitlements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button("Cancel") { viewModel.onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button("Signieren") { viewModel.handleProceed() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func entitlementRow(_ entry: EntitlementEntry) -> some View {
        let allowed = viewModel.isEntitlementAllowed(entry.key)
        return DisclosureGroup {
            Text(entry.key).font(.caption.monospaced()).textSelection(.enabled)
                .foregroundStyle(.secondary)
            if !allowed {
                Text("Unavailable for This Account").foregroundStyle(.orange)
            }
            switch entry.type {
            case .boolean:
                Toggle("Aktiviert", isOn: viewModel.bindingForBool(entryID: entry.id))
                    .disabled(!allowed)
            case .string, .number:
                TextField("Wert", text: viewModel.bindingForString(entryID: entry.id))
                    .textInputAutocapitalization(.never).autocorrectionDisabled().disabled(!allowed)
            case .stringArray:
                ForEach(Array(entry.arrayValue.enumerated()), id: \.offset) { index, value in
                    HStack {
                        Text(value).font(.subheadline.monospaced()).textSelection(.enabled)
                        Spacer()
                        SwiftUI.Button(role: .destructive) {
                            viewModel.removeArrayItem(entryID: entry.id, index: index)
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).disabled(!allowed)
                    }
                }
                HStack {
                    TextField("Neuer Wert", text: Binding(
                        get: { arrayDrafts[entry.id] ?? "" }, set: { arrayDrafts[entry.id] = $0 }
                    )).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SwiftUI.Button {
                        viewModel.newArrayItemText = arrayDrafts[entry.id] ?? ""
                        viewModel.addArrayItem(entryID: entry.id)
                        arrayDrafts[entry.id] = ""
                    } label: { Image(systemName: "plus.circle") }
                        .buttonStyle(.borderless)
                        .disabled(!allowed || (arrayDrafts[entry.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            SwiftUI.Button("Entitlement entfernen", role: .destructive) {
                viewModel.deleteEntry(entryID: entry.id)
            }.buttonStyle(.borderless)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(Entitlement.allKnown.first(where: { $0.id == entry.key })?.displayName ?? entry.key)
                    .foregroundStyle(.primary)
                Text(entry.key).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var customEditor: some View {
        NavigationStack {
            Form {
                Section("Key") {
                    TextField("com.apple.…", text: $viewModel.newCustomKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }.listRowBackground(ZLoaderGlassBackground())
                Section("Typ") {
                    Picker("Werttyp", selection: $viewModel.newCustomType) {
                        ForEach(EntitlementValueType.allCases) { Text($0.rawValue).tag($0) }
                    }
                }.listRowBackground(ZLoaderGlassBackground())
                Section("Wert") {
                    switch viewModel.newCustomType {
                    case .boolean: Toggle("Aktiviert", isOn: $viewModel.newCustomBool)
                    case .string, .number: TextField("Wert", text: $viewModel.newCustomString)
                    case .stringArray: TextField("Werte, mit Komma getrennt", text: $viewModel.newCustomArrayText)
                    }
                }.listRowBackground(ZLoaderGlassBackground())
            }
            .navigationTitle("Add Entitlement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button("Cancel") { viewModel.isShowingAddCustomSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button("Add") {
                        viewModel.commitCustomKey()
                        viewModel.isShowingAddCustomSheet = false
                    }.disabled(viewModel.newCustomKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
