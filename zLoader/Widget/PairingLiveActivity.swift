import SwiftUI
import WidgetKit
import ActivityKit

struct PairingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PairingActivityAttributes.self) { context in
            HStack {
                Image(systemName: context.state.complete ? "checkmark.seal.fill" : "antenna.radiowaves.left.and.right")
                VStack(alignment: .leading) {
                    Text("zLoader · Lokales Pairing").font(.headline)
                    Text(context.state.status).font(.caption)
                }
                Spacer()
                if let pin = context.state.pin { Text(pin).font(.title2.monospacedDigit().bold()).privacySensitive() }
            }
            .padding()
            .activityBackgroundTint(Color(uiColor: .systemBackground))
            .activitySystemActionForegroundColor(Color(uiColor: .label))
            .widgetURL(URL(string: "zloader://local-pairing"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("zLoader", systemImage: "antenna.radiowaves.left.and.right") }
                DynamicIslandExpandedRegion(.trailing) {
                    if let pin = context.state.pin { Text(pin).monospacedDigit().bold().privacySensitive() }
                }
                DynamicIslandExpandedRegion(.bottom) { Text(context.state.status).font(.caption) }
            } compactLeading: {
                Image(systemName: context.state.complete ? "checkmark" : "antenna.radiowaves.left.and.right")
            } compactTrailing: {
                if let pin = context.state.pin { Text(pin).font(.caption2.monospacedDigit()).privacySensitive() }
                else { Text("Pair") }
            } minimal: {
                Image(systemName: "antenna.radiowaves.left.and.right")
            }
            .widgetURL(URL(string: "zloader://local-pairing"))
        }
    }
}
