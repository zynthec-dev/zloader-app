import SwiftUI

/// Uses the existing per-source sort field, without changing the Core Data schema.
enum SourceOrderSettings {
    static let key = "zLoader.sourceOrder"
    static func rank(_ identifier: String) -> String {
        if identifier == Source.zLoaderIdentifier { return "00000000" }
        let ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        let index = ids.firstIndex(of: identifier).map { $0 + 1 } ?? 99999999
        return String(format: "%08d", index)
    }
}

struct SourceOrderItem: Identifiable {
    let id: String
    let name: String
}

struct SourceOrderView: View {
    @State var items: [SourceOrderItem]
    let save: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    HStack {
                        Text(item.id == Source.zLoaderIdentifier ? "zLoader" : item.name)
                        if item.id == Source.zLoaderIdentifier { Spacer(); Image(systemName: "pin.fill").foregroundStyle(.secondary) }
                    }
                    .moveDisabled(item.id == Source.zLoaderIdentifier)
                }
                .onMove { offsets, destination in
                    guard !offsets.contains(where: { items[$0].id == Source.zLoaderIdentifier }) else { return }
                    let lower = items.first?.id == Source.zLoaderIdentifier ? 1 : 0
                    items.move(fromOffsets: offsets, toOffset: max(lower, destination))
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Sort Sources")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SwiftUI.Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    SwiftUI.Button { save(items.map(\.id)); dismiss() } label: { Image(systemName: "checkmark") }
                    .accessibilityLabel(Text("Save Changes"))
                }
            }
        }
    }
}
