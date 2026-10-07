//
//  OnboardingView.swift
//  ZLoader
//
//  Created by SternXD on 9/13/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Minimuxer
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    var onFinish: (() -> Void)? = nil
    @AppStorage("zLoader.onboarding.currentStep") private var currentStep = 0
    @AppStorage("zLoader.onboarding.eligibleForTunnel") private var eligibleForTunnel = false
    @State private var membershipError: String?
    private var totalSteps: Int { eligibleForTunnel ? 6 : 5 }

    var body: some View {
        ZStack {
            #if !os(tvOS)
                Color(uiColor: .settingsBackground).ignoresSafeArea()
            #else
                Color.black.ignoresSafeArea()
            #endif

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                TabView(selection: $currentStep) {
                    WelcomeStep(onNext: { currentStep += 1 })
                        .tag(0)

                    ExternalLocalTunnelStep(onNext: { currentStep += 1 })
                        .tag(1)

                    PairingFileStep(onNext: { currentStep += 1 })
                        .tag(2)

                    AppleIDStep(onNext: {
                        Task { @MainActor in
                            guard AuthManager.shared.isAuthenticated else {
                                eligibleForTunnel = false
                                currentStep = 4
                                return
                            }
                            do {
                                eligibleForTunnel = try await AuthManager.shared.getAuthenticatedTeam().type.isPaid
                                currentStep = 4
                            } catch { membershipError = error.localizedDescription }
                        }
                    })
                        .tag(3)

                    if eligibleForTunnel {
                        Group {
                            if currentStep == 4 {
                                InternalTunnelStep(onNext: { currentStep = 5 })
                            }
                        }.tag(4)
                    }
                    CompleteStep(onFinish: complete)
                        .tag(eligibleForTunnel ? 5 : 4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentStep)
                #if !os(tvOS)
                    .highPriorityGesture(
                        DragGesture().onEnded { value in
                            if value.translation.width > 50, currentStep > 0, currentStep < totalSteps - 1 {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentStep -= 1
                                }
                            }
                        }
                    )
                #endif
            }
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: TunnelBootstrapPayload.pendingKey) {
                eligibleForTunnel = true
                currentStep = 4
            }
        }
        .alert("Could Not Verify Developer Team", isPresented: Binding(
            get: { membershipError != nil }, set: { if !$0 { membershipError = nil } }
        )) { SwiftUI.Button("OK", role: .cancel) {} }
        message: { Text(membershipError ?? "") }
    }



    private var topBar: some View {
        ZStack {
            HStack(spacing: 6) {
                ForEach(0 ..< totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.accentColor : Color.primary.opacity(0.18))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .zLoaderGlassSurface()
            .clipShape(Capsule())

            if currentStep > 0 && currentStep < totalSteps - 1 {
                HStack {
                    SwiftUI.Button(action: { currentStep -= 1 }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 44)
    }

    private func complete() {
        UserDefaults.standard.hasCompletedOnboarding = true
        currentStep = 0
        eligibleForTunnel = false
        UserDefaults.standard.synchronize()
        onFinish?()
    }
}

private struct WelcomeStep: View {
    let onNext: () -> Void
    @State private var isBreathing = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") ?? UIImage(systemName: "app.fill")!)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .scaleEffect(isBreathing ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isBreathing)
                .onAppear { isBreathing = true }

            VStack(spacing: 8) {
                Text(NSLocalizedString("Welcome to zLoader", comment: ""))
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("Sideload and refresh apps directly on your device, untethered from a computer.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 18) {
                featureRow(
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue,
                    title: NSLocalizedString("On-Device Sideloading", comment: ""),
                    description: NSLocalizedString("Install and refresh apps using an on-device local loopback VPN tunnel.", comment: "")
                )

                featureRow(
                    icon: "doc.badge.gearshape",
                    color: .orange,
                    title: NSLocalizedString("Device Pairing", comment: ""),
                    description: String(
                        format: NSLocalizedString("A one-time pairing file connects zLoader to %@ device services.", comment: ""),
                        ProcessInfo.processInfo.platformName
                    )
                )

                featureRow(
                    icon: "person.crop.circle.badge.checkmark",
                    color: .green,
                    title: NSLocalizedString("Personal Signing", comment: ""),
                    description: NSLocalizedString("Use your own Apple ID to sign apps with standard development certificates.", comment: "")
                )
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 28)
            .padding(.top, 12)

            Spacer()

            SwiftUI.Button(action: onNext) {
                Text(NSLocalizedString("Get Started", comment: ""))
                    .font(.headline)
                    .foregroundColor(Color(uiColor: UIColor.altPrimary.contrastingText))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .zLoaderGlassSurface(cornerRadius: 14, interactive: true, prominent: true)
                    .cornerRadius(14)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct PairingFileStep: View {
    let onNext: () -> Void
    @State private var hasPairingFile = PairingFileManager.shared.hasPairingFile()
    @State private var isShowingFilePicker = false
    @State private var isShowingWirelessPairing = false
    @State private var errorMessage: String? = nil

    private let contentTypes: [UTType] = PairingFileManager.supportedContentTypes

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: hasPairingFile ? "checkmark.seal.fill" : "doc.badge.gearshape.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(hasPairingFile ? .green : .accentColor)
                .animation(.easeInOut, value: hasPairingFile)

            VStack(spacing: 8) {
                Text(NSLocalizedString("Pairing File", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(String(
                    format: NSLocalizedString("Pair wirelessly on your device, or import an existing pairing file, to connect zLoader to %@ device services.", comment: ""),
                    ProcessInfo.processInfo.platformName
                ))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }

            if hasPairingFile {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("Pairing file detected and loaded.", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            VStack(spacing: 12) {
                #if !os(tvOS)
                    if #available(iOS 26.0, *) {
                        SwiftUI.Button(action: { isShowingWirelessPairing = true }) {
                            Label("Self-Pairing", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.headline)
                                .foregroundStyle(Color(uiColor: UIColor.altPrimary.contrastingText))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .zLoaderGlassSurface(cornerRadius: 12, interactive: true, prominent: true)
                        }
                    }

                    SwiftUI.Button(action: { isShowingFilePicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                            Text(hasPairingFile
                                ? NSLocalizedString("Choose Different File", comment: "")
                                : NSLocalizedString("Select Pairing File", comment: ""))
                        }
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .zLoaderGlassSurface()
                        .cornerRadius(12)
                    }

                    SwiftUI.Button(action: {
                        UIApplication.shared.open(AppConstants.URLs.pairingDocumentation)
                    }) {
                        Text(NSLocalizedString("How do I get a pairing file?", comment: ""))
                            .font(.footnote)
                            .foregroundColor(.accentColor)
                    }
                #endif

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("Continue", comment: ""))
                        .font(.headline)
                        .foregroundColor(Color(uiColor: UIColor.altPrimary.contrastingText))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .zLoaderGlassSurface(cornerRadius: 14, interactive: true, prominent: true)
                        .cornerRadius(14)
                }
                .disabled(!hasPairingFile)

                if !hasPairingFile {
                    SwiftUI.Button(action: onNext) {
                        Text(NSLocalizedString("Set Up Later", comment: ""))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        #if !os(tvOS)
        .sheet(isPresented: $isShowingWirelessPairing, onDismiss: {
            hasPairingFile = PairingFileManager.shared.hasPairingFile()
        }) {
            if #available(iOS 26.0, *) {
                NavigationStack {
                    WirelessPairView(startsAsClient: false, selfPairing: true, onPairingFileReady: { url in
                        try PairingFileManager.shared.importPairingFile(from: url, preferred: .rppairing)
                        PairingFileManager.shared.preferredProtocol = .rppairing
                        hasPairingFile = PairingFileManager.shared.hasPairingFile()
                        errorMessage = nil
                    })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            SwiftUI.Button("Close") { isShowingWirelessPairing = false }
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: contentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                do {
                    try PairingFileManager.shared.importPairingFile(from: url)
                    hasPairingFile = true
                    errorMessage = nil
                    onNext()
                } catch {
                    errorMessage = error.localizedDescription
                }
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
        #endif
    }
}

private struct ExternalLocalTunnelStep: View {
    @ObservedObject private var connection = ConnectionConfig.shared
    let onNext: () -> Void
    @State private var isConnected = false
    @State private var errorMessage: String? = nil
    @State private var checking = false
    @State private var usingInternal = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()

                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "network")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.accentColor)

                        if isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                            #if !os(tvOS)
                                .background(Circle().fill(Color(uiColor: .settingsBackground)))
                            #else
                                .background(Circle().fill(Color.black))
                            #endif
                                .offset(x: 4, y: 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut, value: isConnected)

                    VStack(spacing: 8) {
                        Text(usingInternal ? NSLocalizedString("Connection", comment: "") : NSLocalizedString("External Local VPN Tunnel", comment: ""))
                            .font(.system(size: 28, weight: .bold))

                        Text(NSLocalizedString("An external local VPN tunnel is required for pairing, installation and refresh. Enable a compatible tunnel in your preferred VPN app. This status checks the device service at the tunnel IP; you can continue even when it is not reachable yet.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Label {
                        VStack(spacing: 4) {
                            Text(isConnected ? "Connected" : "Not Connected")
                            Text(connection.tunnelPeerReachable ? (connection.tunnelPeerIp ?? connection.effectiveTunnelPeerIP) : connection.effectiveTunnelPeerIP)
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                            if !isConnected {
                                Text("The device service is not reachable yet. A VPN may be enabled even when this probe fails.")
                                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }
                        }
                    } icon: {
                        Image(systemName: isConnected ? "checkmark.circle.fill" : "network")
                            .foregroundStyle(isConnected ? Color.green : Color.secondary)
                    }
                    .font(.footnote)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        SwiftUI.Button(action: onNext) {
                            Text(NSLocalizedString("Continue", comment: ""))
                                .font(.headline)
                                .foregroundColor(Color(uiColor: UIColor.altPrimary.contrastingText))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .zLoaderGlassSurface(cornerRadius: 14, interactive: true, prominent: true)
                                .cornerRadius(14)
                        }
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .onReceive(connection.$tunnelPeerReachable.combineLatest(connection.$overrideTunnelPeerReachable)) { discovered, override in
            guard !usingInternal else { return }
            isConnected = connection.isEffectivePeerReachable(discovered: discovered, override: override)
            if isConnected { errorMessage = nil }
        }
        .task { await checkStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await checkStatus() }
        }
    }

    @MainActor private func checkStatus() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        #if os(iOS)
        usingInternal = UserDefaults.standard.bool(forKey: "zLoader.useInternalVPN")
            && EmbeddedTunnel.shared.unavailableReason == nil
        if usingInternal {
            do {
                try await ZLoaderTransport.withLease { _ = try await fetchUDID(forceLive: true) }
                isConnected = true
                errorMessage = nil
            } catch {
                isConnected = false
                errorMessage = error.localizedDescription
            }
            return
        }
        #endif
        connection.useLocalVPN = true
        syncMinimuxerBackendFromUserDefaults()
        await bindConnectionConfig()
        await minimuxer.network.refreshEndpoint()
        isConnected = ConnectionConfig.shared.tunnelPeerActive == .yes
        if isConnected { errorMessage = nil }
    }


}

private struct InternalTunnelStep: View {
    #if os(iOS)
    @ObservedObject private var provisioning = SelfProvisioning.shared
    #endif
    let onNext: () -> Void
    @State private var ready = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 64)).foregroundStyle(Color.accentColor)
                Text("Use the Internal Tunnel?").font(.system(size: 28, weight: .bold)).multilineTextAlignment(.center)
                #if os(iOS)
                SelfProvisioningView(onReady: { ready = true },
                                     automaticallyVerify: UserDefaults.standard.bool(forKey: TunnelBootstrapPayload.pendingKey))
                #endif
                if ready {
                    SwiftUI.Button("Continue", action: onNext).buttonStyle(OnboardingPrimaryButtonStyle())
                } else {
                    SwiftUI.Button("Use External Local VPN Tunnel", action: onNext)
                        .buttonStyle(OnboardingPrimaryButtonStyle(secondary: true))
                        #if os(iOS)
                        .disabled(provisioning.busy)
                        #endif
                }
            }.padding(32).frame(maxWidth: 480).frame(maxWidth: .infinity)
        }
    }
}

private struct AppleIDStep: View {
    let onNext: () -> Void
    @State private var isAuthenticated = AuthManager.shared.isAuthenticated
    @State private var isSigningIn = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: isAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(isAuthenticated ? .green : .accentColor)
                .animation(.easeInOut, value: isAuthenticated)

            VStack(spacing: 8) {
                Text(NSLocalizedString("Apple ID", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(NSLocalizedString("zLoader requires an Apple ID to create development certificates and provisioning profiles for signing apps.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if isAuthenticated {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(AuthManager.shared.currentAppleID ?? NSLocalizedString("Signed in", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                SwiftUI.Button(action: {
                    Task {
                        isSigningIn = true
                        errorMessage = nil
                        defer { isSigningIn = false }

                        do {
                            _ = try await AuthManager.shared.signIn(
                                presentingViewController: UIApplication.shared.topViewController(),
                                skipResign: true,
                                skipHowTos: true
                            )
                            isAuthenticated = true
                            onNext()
                        } catch {
                            if !(error is CancellationError) {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        if isSigningIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: "key.fill")
                        }
                        Text(NSLocalizedString("Sign In with Apple ID", comment: ""))
                    }
                    .font(.headline)
                    .foregroundColor(Color(uiColor: UIColor.altPrimary.contrastingText))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .zLoaderGlassSurface(cornerRadius: 14, interactive: true, prominent: true)
                    .cornerRadius(12)
                }
                .disabled(isSigningIn)
                .frame(maxWidth: 420)
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("Continue", comment: ""))
                        .font(.headline)
                        .foregroundColor(Color(uiColor: UIColor.altPrimary.contrastingText))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .zLoaderGlassSurface(cornerRadius: 14, interactive: true, prominent: true)
                        .cornerRadius(14)
                }
                .disabled(!isAuthenticated && !isSigningIn)

                SwiftUI.Button(action: onNext) {
                    Text(NSLocalizedString("Set Up Later", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .disabled(isSigningIn)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

private struct CompleteStep: View {
    let onFinish: () -> Void

    private var hasPairingFile: Bool {
        PairingFileManager.shared.hasPairingFile()
    }

    private var isAuthenticated: Bool {
        AuthManager.shared.isAuthenticated
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: hasPairingFile ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(hasPairingFile ? .green : .orange)

            VStack(spacing: 8) {
                Text(hasPairingFile
                    ? NSLocalizedString("You're All Set!", comment: "")
                    : NSLocalizedString("Setup Incomplete", comment: ""))
                    .font(.system(size: 28, weight: .bold))

                Text(hasPairingFile
                    ? NSLocalizedString("zLoader setup is complete. You can now install and refresh apps.", comment: "")
                    : NSLocalizedString("You can enter zLoader, but a pairing file is required before you can install or refresh apps.", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                summaryRow(
                    title: NSLocalizedString("Pairing File", comment: ""),
                    isConfigured: hasPairingFile,
                    warning: NSLocalizedString("Required before installing or refreshing apps", comment: "")
                )

                Divider()

                summaryRow(
                    title: NSLocalizedString("Apple ID", comment: ""),
                    isConfigured: isAuthenticated,
                    warning: NSLocalizedString("Can be added anytime in Settings", comment: "")
                )
            }
            .padding(16)
            .zLoaderGlassSurface()
            .cornerRadius(16)
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)

            Spacer()

            SwiftUI.Button(action: onFinish) {
                Text(NSLocalizedString("Open zLoader", comment: ""))
                    .font(.headline)
                    .foregroundColor(Color(uiColor: UIColor.altPrimary.contrastingText))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .zLoaderGlassSurface(cornerRadius: 14, interactive: true, prominent: true)
                    .cornerRadius(14)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func summaryRow(title: String, isConfigured: Bool, warning: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isConfigured ? .green : .orange)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if isConfigured {
                    Text(NSLocalizedString("Configured", comment: ""))
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text(NSLocalizedString("Not Configured", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)

                    Text(warning)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    var secondary = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(secondary ? Color.accentColor : Color(uiColor: UIColor.altPrimary.contrastingText))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .zLoaderGlassSurface(cornerRadius: 14, interactive: true, prominent: !secondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}
