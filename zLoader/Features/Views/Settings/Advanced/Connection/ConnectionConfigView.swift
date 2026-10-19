//
//  ConnectionConfigView.swift
//  ZLoader
//
//  Created by Magesh K on 02/03/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import Combine
import Minimuxer
import Darwin

private typealias SButton = SwiftUI.Button

enum ActiveState: String {
    case yes = "Yes"
    case no = "No"
}

struct AnimatedCheckmarkView: View {
    @State private var outerCircleTrim: CGFloat = 0.0
    @State private var checkmarkTrim: CGFloat = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.2), lineWidth: 4)
                .frame(width: 70, height: 70)

            Circle()
                .trim(from: 0.0, to: outerCircleTrim)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))

            Path { path in
                path.move(to: CGPoint(x: 21, y: 35))
                path.addLine(to: CGPoint(x: 30, y: 44))
                path.addLine(to: CGPoint(x: 49, y: 25))
            }
            .trim(from: 0.0, to: checkmarkTrim)
            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .frame(width: 70, height: 70)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) {
                outerCircleTrim = 1.0
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.4)) {
                checkmarkTrim = 1.0
            }
        }
    }
}

#if os(iOS)
struct ConnectionConfigView: View {
    @ObservedObject private var config = ConnectionConfig.shared
    @State private var checkingConnection = false
    @State private var connectionError: String?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        List {
            Section("Connection Method") {
                Text("Local tunnel VPN via an external app")
                WireGuardSetupView()
            }.zLoaderSettingsRows()
            Section {
                LabeledContent("Interface") { Text(verbatim: config.formattedTunnelIface ?? NSLocalizedString("Not Detected", comment: "")) }
                LabeledContent("Peer") { Text(verbatim: config.formattedTunnelPeer ?? NSLocalizedString("Not Detected", comment: "")) }
                LabeledContent("Endpoint") { Text(checkingConnection ? "Checking…" : (config.tunnelPeerActive == .yes ? "Reachable" : "Not Reachable")) }
            } header: {
                Text("Tunnel Data")
            } footer: {
                if let connectionError { Text(verbatim: connectionError) }
            }.zLoaderSettingsRows()
        }
        .navigationTitle("Connection Settings")
        .zLoaderSettingsPage()
        .labelStyle(.titleAndIcon)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            config.useLocalVPN = true
            config.overrideTunnelPeerIp = ""
            checkingConnection = true
            connectionError = nil
            do {
                try await WireGuardLocalTunnel.shared.prepare()
                syncMinimuxerBackendFromUserDefaults()
                await minimuxer.network.refreshEndpoint()
                await bindConnectionConfig()
                _ = try await fetchUDID(forceLive: true)
            } catch is CancellationError {
                // Leaving the screen releases this lease, without interrupting
                // another operation that still owns the tunnel.
            } catch {
                connectionError = error.localizedDescription
            }
            checkingConnection = false
        }

    }


}
#else
struct ConnectionConfigView: View {
    @ObservedObject private var config = ConnectionConfig.shared
    var body: some View {
        List {
            Section("Remote Device Connection") {
                TextField("Device IP", text: $config.remoteServerIp)
                Text("An external local VPN tunnel is required on iPhone and iPad.")
            }.zLoaderSettingsRows()
        }.navigationTitle("Connection")
        .zLoaderSettingsPage()
    }
}
#endif
