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
    @State private var paidTeam = false

    var body: some View {
        List {
            Section("Connection Method") {
                Picker("VPN", selection: $useInternal) {
                    Text("External Local VPN Tunnel (extern)").tag(false)
                    if EmbeddedTunnel.shared.unavailableReason == nil {
                        Text("zLoader (intern)").tag(true)
                    }
                }.pickerStyle(.inline)
                if useInternal {
                    Text("zLoader connects its internal tunnel only while pairing, installation or refresh needs it. External tunnel shortcuts are disabled for this connection method.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ExternalLocalTunnelSetupView(isExternalSelected: !useInternal)
                    .disabled(useInternal)
                    .opacity(useInternal ? 0.45 : 1)
            }.listRowBackground(ZLoaderGlassBackground())
            if paidTeam {
                Section("Optional Internal Tunnel") {
                    SelfProvisioningView(automaticallyVerify: UserDefaults.standard.bool(forKey: TunnelBootstrapPayload.pendingKey))
                    if EmbeddedTunnel.shared.unavailableReason != nil {
                        Text("The internal tunnel stays disabled until self-signing succeeds. Leave your external tunnel enabled during this operation.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.listRowBackground(ZLoaderGlassBackground())
            }
            if useInternal {
                Section {
                    TextField("Local Peer Address", text: $peer)
                    TextField("Local Interface Address", text: $interface)
                } header: { Text("Internal Tunnel Addresses") }
                  footer: { Text("Choose two different private IPv4 addresses. These are virtual tunnel addresses, not Wi-Fi addresses. Changes apply the next time the tunnel connects.") }.listRowBackground(ZLoaderGlassBackground())
            }
            Section("Device Endpoint") {
                LabeledContent("Interface", value: config.formattedTunnelIface ?? "Not Detected")
                LabeledContent("Peer", value: config.formattedTunnelPeer ?? "Not Detected")
                LabeledContent("Reachable", value: config.tunnelPeerActive.rawValue)
            }.listRowBackground(ZLoaderGlassBackground())
        }
        .navigationTitle("Connection")
        .labelStyle(.titleOnly)
        .task {
            paidTeam = (try? await AuthManager.shared.getAuthenticatedTeam().type.isPaid) == true
            if EmbeddedTunnel.shared.unavailableReason != nil { useInternal = false }
            config.useLocalVPN = true
            if !useInternal { config.overrideTunnelPeerIp = "" }
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
