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
    @AppStorage("zLoader.useInternalVPN") private var useInternal = false
    @AppStorage("zLoader.internalPeer") private var peer = "10.7.0.1"
    @AppStorage("zLoader.internalInterface") private var interface = "10.7.1.1"
    @ObservedObject private var provisioning = SelfProvisioning.shared
    @State private var showsTunnelSetup = false
    @State private var selectingMethod = false
    var body: some View {
        List {
            Section("Connection Method") {
                Picker("VPN", selection: Binding(get: { useInternal }, set: selectMethod)) {
                    Text("Local tunnel VPN via an external app").tag(false)
                    Text("Integrated zLoader Local Tunnel (Recommended)").tag(true)
                }.pickerStyle(.inline)
                    .disabled(selectingMethod || provisioning.busy)
            }.listRowBackground(ZLoaderGlassBackground())
            Section("Tunnel Data") {
                LabeledContent("Interface") { Text(verbatim: config.formattedTunnelIface ?? NSLocalizedString("Not Detected", comment: "")) }
                LabeledContent("Peer") { Text(verbatim: config.formattedTunnelPeer ?? NSLocalizedString("Not Detected", comment: "")) }
                LabeledContent("Endpoint") { Text(config.tunnelPeerActive == .yes ? "Reachable" : "Not Reachable") }
            }.listRowBackground(ZLoaderGlassBackground())
        }
        .navigationTitle("Connection Settings")
        .labelStyle(.titleOnly)
        .sheet(isPresented: $showsTunnelSetup) {
            NavigationStack {
                Form {
                    Section("zLoader Local Tunnel") {
                        SelfProvisioningView(onReady: { showsTunnelSetup = false })
                    }.listRowBackground(ZLoaderGlassBackground())
                }
                .navigationTitle("zLoader Local Tunnel")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SButton("Cancel", role: .cancel) { showsTunnelSetup = false }
                            .disabled(provisioning.busy)
                    }
                }
            }
            .interactiveDismissDisabled(provisioning.busy)
        }
        .task {
            if EmbeddedTunnel.shared.unavailableReason != nil { useInternal = false }
            config.useLocalVPN = true
            config.overrideTunnelPeerIp = useInternal ? peer : ""
            await bindConnectionConfig()
        }
        .onChange(of: useInternal) { _, internalVPN in
            config.useLocalVPN = true
            config.overrideTunnelPeerIp = internalVPN ? peer : ""
            Task {
                if !internalVPN { await EmbeddedTunnel.shared.stop() }
                syncMinimuxerBackendFromUserDefaults()
                await bindConnectionConfig()
            }
        }
    }

    private func selectMethod(_ internalVPN: Bool) {
        guard !selectingMethod, !provisioning.busy else { return }
        if !internalVPN {
            useInternal = false
            return
        }
        selectingMethod = true
        Task { @MainActor in
            defer { selectingMethod = false }
            if await EmbeddedTunnel.shared.hasSavedConfiguration() {
                useInternal = true
            } else {
                // Keep the external transport selected until setup verifies
                // the new internal tunnel; self-signing needs that connection.
                showsTunnelSetup = true
            }
        }
    }
}
#else
struct ConnectionConfigView: View {
    @ObservedObject private var config = ConnectionConfig.shared
    var body: some View {
        Form {
            Section("Remote Device Connection") {
                TextField("Device IP", text: $config.remoteServerIp)
                Text("VPN configuration and the optional internal tunnel are available on iPhone and iPad.")
            }.listRowBackground(ZLoaderGlassBackground())
        }.navigationTitle("Connection")
    }
}
#endif
