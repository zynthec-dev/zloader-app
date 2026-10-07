//
//  WirelessPairViewModel.swift
//  ZLoader
//
//  Created by Magesh K on 04/07/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Network
import Minimuxer
import MinimuxerCommon

enum SelectedEndpointOption: Equatable {
    case discovered(WirelessPairTarget)
    case configuredFallback
}

enum PairingMode: String {
    case server
    case client
}

struct WirelessPairTarget: Identifiable, Hashable {
    var id: String { service.id }
    let service: DiscoveredService
    var ipv4: String?
    var ipv6: String?
    var port: UInt16
    
    var name: String {
        var records = service.txtRecords
        if case .bonjour(let txt) = service.result.metadata {
            records += txt.dictionary.map { (key: $0.key, value: $0.value) }
        }
        // NetService results store TXT records separately from NWBrowser metadata.
        // Prefer an advertised device name over a UUID-like service instance.
        for key in ["name", "devicename", "device_name", "displayname"] {
            if let record = records.first(where: {
                $0.key.lowercased() == key && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) {
                return record.value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return service.name
    }

    var rawType: String { service.type }
    
    var model: String? {
        if case .bonjour(let txt) = service.result.metadata {
            return txt.dictionary["model"]
        }
        return nil
    }
    
    var uuid: String? {
        if case .bonjour(let txt) = service.result.metadata {
            return txt.dictionary["uuid"] ?? txt.dictionary["deviceid"]
        }
        return nil
    }
    
    var typeBadge: String {
        if service.type.contains("manual-pairing") { return "Apple TV / Manual" }
        if service.type.contains("pairable-host") { return "Pairable Host" }
        if service.type.contains("remotepairing") { return "Remote Device" }
        return BonjourDiscoveryManager.friendlyName(for: service.type) ?? service.type
    }
    
    var iconName: String {
        if service.type.contains("manual-pairing") { return "appletv.fill" }
        if service.type.contains("pairable-host") { return "macbook.and.iphone" }
        return "antenna.radiowaves.left.and.right"
    }
}

@MainActor
final class WirelessPairViewModel: ObservableObject {
    static let shared = WirelessPairViewModel()
    @Published var confirmationMessage: String?
    @Published var isSavingLockdown = false
    // Server Advertising State
    @Published var statusText = NSLocalizedString("Ready to pair", comment: "")
    @Published var subStatusText = NSLocalizedString("Tap Start to advertise this device on the local network.", comment: "")
    @Published var pinCode: String? = nil
    @Published var isAdvertising = false
    @Published var pairedDevice: MinimuxerPairedDevice? = nil
    @Published var errorMessage: String? = nil
    @Published var serviceID: String? = nil
    @Published var port: Int? = nil
    
    // Sheet / Dialog State
    @Published var isTargetDialogPresented = false
    @Published var dialogMode: PairingMode = .server
    @Published var selectedServerInterfaceId: String? = nil
    @Published var selectedOption: SelectedEndpointOption = .configuredFallback
    
    // Discovery State
    @Published var discoveredTargets: [WirelessPairTarget] = []
    @Published var isScanning = false
    @Published var activeInterfaces: [LocalInterfaceInfo] = []
    
    // Client PIN Prompt State
    @Published var isPinPromptPresented = false
    @Published var enteredPin = ""
    private var pinPromptCallback: ((String) -> Void)?
    
    
    private let pairingServiceTypes = [
        "_remotepairing-manual-pairing._tcp",
        "_remotepairing._tcp",
        "_remotepairing-pairable-host._tcp"
    ]
    
    private let bonjour = BonjourDiscoveryManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var resolvingTasks: [String: Task<Void, Never>] = [:]
    
    var fallbackConfigEndpoint: (ip: String, port: UInt16) {
        let config = ConnectionConfig.shared
        let port = remotePairingPortCache != 0 ? remotePairingPortCache : AppConstants.Minimuxer.remotePairingPort

        guard config.useLocalVPN else {
            let remote = config.remoteServerIp.trimmingCharacters(in: .whitespacesAndNewlines)
            return (ip: !remote.isEmpty ? remote : AppConstants.Connection.defaultRemoteServerIP, port: port)
        }

        guard let ip = [config.overrideTunnelPeerIp, config.tunnelPeerIp]
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            return (ip: AppConstants.Connection.defaultOverrideIP, port: port)
        }

        return (ip: ip, port: port)
    }
    
    private(set) var isSelfPairing = false

    func configurePurpose(selfPairing: Bool, onPairingFileReady: ((URL) throws -> Void)?) {
        guard pairingTask == nil, !isAdvertising, !isSavingLockdown else { return }
        if isSelfPairing != selfPairing {
            pairedDevice = nil
            confirmationMessage = nil
            self.onPairingFileReady = nil
        }
        isSelfPairing = selfPairing
        if let onPairingFileReady { self.onPairingFileReady = onPairingFileReady }
    }

    var onPairingFileReady: ((URL) throws -> Void)?

    init(onPairingFileReady: ((URL) throws -> Void)? = nil) {
        self.onPairingFileReady = onPairingFileReady
        debugLog("[WirelessPairViewModel] init() initializing...")
        activeInterfaces = minimuxer.network.activeInterfaces
        
        // Setup closures once
        wirelessPairing.onReadyToPair = { [weak self] (serviceID: String, port: Int) in
            debugLog("[WirelessPairViewModel] onReadyToPair callback received: serviceID='\(serviceID)', port=\(port)")
            Task { @MainActor in
                guard let self = self, self.isAdvertising else { return }
                self.serviceID = serviceID
                self.port = port
                self.statusText = NSLocalizedString("Pairing Server Ready", comment: "")
                self.subStatusText = self.isSelfPairing ? "Open Settings → Privacy & Security → Developer Mode on this device." : "Open the pairing settings on the other device and select zLoader."
                PairingActivityController.shared.update(status: self.statusText, pin: nil)
                if self.showInstructionsWhenReady {
                    self.showInstructionsWhenReady = false
                    self.showSelfPairingInstructions = true
                }
            }
        }
        
        wirelessPairing.onPinReceived = { [weak self] (pin: String) in
            debugLog("[WirelessPairViewModel] Pairing PIN received")
            Task { @MainActor in
                guard let self = self, self.isAdvertising else { return }
                self.pinCode = pin
                PairingActivityController.shared.update(status: "Enter Pairing PIN", pin: pin)
                self.statusText = NSLocalizedString("Device Connected", comment: "")
                self.subStatusText = NSLocalizedString("Enter the pairing code shown below on your other device settings screen.", comment: "")
            }
        }
        
        wirelessPairing.onRequestPin = { [weak self] (submitPin: @escaping (String) -> Void) in
            debugLog("[WirelessPairViewModel] onRequestPin callback received from wirelessPairing")
            Task { @MainActor in
                guard let self = self else { return }
                self.pinPromptCallback = submitPin
                self.enteredPin = ""
                self.isPinPromptPresented = true
                self.statusText = NSLocalizedString("Enter Pairing PIN", comment: "")
                self.subStatusText = NSLocalizedString("Enter the 6-digit code shown on your Apple TV / device screen.", comment: "")
            }
        }
    }
    
    func submitEnteredPin() {
        let pin = enteredPin.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPin = pin.isEmpty ? "000000" : pin
        debugLog("[WirelessPairViewModel] Submitting pairing PIN")
        pinPromptCallback?(finalPin)
        pinPromptCallback = nil
        isPinPromptPresented = false
        enteredPin = ""
    }
    
    func cancelPinPrompt() {
        debugLog("[WirelessPairViewModel] cancelPinPrompt() cancelling PIN prompt")
        pinPromptCallback?("000000")
        pinPromptCallback = nil
        isPinPromptPresented = false
        enteredPin = ""
    }
    
    private var discoveryTask: Task<Void, Never>?
    private var pairingTask: Task<Void, Never>?
    @Published var showSelfPairingInstructions = false
    private var showInstructionsWhenReady = false
    
    func refreshInterfaces() {
        debugLog("[WirelessPairViewModel] refreshInterfaces() scanning active interfaces...")
        activeInterfaces = minimuxer.network.activeInterfaces
        debugLog("[WirelessPairViewModel] refreshInterfaces() scan completed, found \(activeInterfaces.count) active interfaces:")
        for iface in activeInterfaces {
            debugLog("[WirelessPairViewModel]  -> \(iface.name) [\(iface.type.rawValue)]: ip=\(iface.ip), ipv6=\(iface.ipv6 ?? "none"), subnet=\(iface.subnet)")
        }
    }
    
    func selectDefaultServerInterface() {
        selectedServerInterfaceId = activeInterfaces
            .first(where: { $0.type == .wifi })?.id 
            ?? activeInterfaces
            .first(where: { $0.type.isVPN })?.id 
            ?? activeInterfaces.first?.id
        debugLog("[WirelessPairViewModel] selectDefaultServerInterface() selected: \(selectedServerInterfaceId ?? "none")")
    }
    
    func selectServerInterface(id: String) {
        debugLog("[WirelessPairViewModel] selectServerInterface(id: '\(id)')")
        selectedServerInterfaceId = id
    }
    
    func selectTarget(_ target: WirelessPairTarget) {
        debugLog("[WirelessPairViewModel] selectTarget() selected: '\(target.name)' (\(target.rawType)) -> v4=\(target.ipv4 ?? "none"), v6=\(target.ipv6 ?? "none"), port=\(target.port)")
        selectedOption = .discovered(target)
    }
    
    func selectFallbackEndpoint() {
        let fallback = fallbackConfigEndpoint
        debugLog("[WirelessPairViewModel] selectFallbackEndpoint() selected fallback: \(fallback.ip):\(fallback.port)")
        selectedOption = .configuredFallback
    }
    
    func isTargetSelected(_ target: WirelessPairTarget) -> Bool {
        if case .discovered(let selected) = selectedOption {
            return selected.id == target.id
        }
        return false
    }
    
    var isFallbackSelected: Bool {
        if case .configuredFallback = selectedOption {
            return true
        }
        return false
    }
    
    func openClientDialog() {
        debugLog("[WirelessPairViewModel] openClientDialog() opening client target pairing sheet")
        dialogMode = .client
        selectedOption = .configuredFallback
        startDiscovery()
        isTargetDialogPresented = true
    }
    
    func openServerDialog() {
        debugLog("[WirelessPairViewModel] openServerDialog() opening server interface selection sheet")
        if isAdvertising {
            debugLog("[WirelessPairViewModel] openServerDialog() already advertising, stopping pairing instead")
            stopPairing()
        } else {
            dialogMode = .server
            refreshInterfaces()
            selectDefaultServerInterface()
            isTargetDialogPresented = true
        }
    }
    
    func onDialogAppear() {
        debugLog("[WirelessPairViewModel] onDialogAppear (mode=\(dialogMode.rawValue), isPresented=\(isTargetDialogPresented))")
        if dialogMode == .server {
            refreshInterfaces()
            if selectedServerInterfaceId == nil {
                selectDefaultServerInterface()
            }
        } else {
            if discoveredTargets.isEmpty && !isScanning {
                debugLog("[WirelessPairViewModel] onDialogAppear discoveredTargets is empty and not scanning -> triggering startDiscovery()")
                startDiscovery()
            }
        }
    }
    
    func onDialogDisappear() {
        debugLog("[WirelessPairViewModel] onDialogDisappear (mode=\(dialogMode.rawValue))")
        if dialogMode == .client {
            stopDiscovery()
        }
    }
    
    func refreshDialog() {
        debugLog("[WirelessPairViewModel] refreshDialog (pull-to-refresh invoked for mode=\(dialogMode.rawValue))")
        if dialogMode == .client {
            startDiscovery()
        } else {
            refreshInterfaces()
        }
    }
    
    func dismissDialog() {
        debugLog("[WirelessPairViewModel] dismissDialog (mode=\(dialogMode.rawValue))")
        if dialogMode == .client {
            stopDiscovery()
        }
        isTargetDialogPresented = false
    }
    
    func confirmSelection() {
        debugLog("[WirelessPairViewModel] confirmSelection() invoked (mode=\(dialogMode.rawValue), option=\(selectedOption))")
        dismissDialog()
        
        if dialogMode == .client {
            switch selectedOption {
            case .discovered(let target):
                let targetIp = target.ipv4 ?? target.ipv6 ?? target.service.name
                let targetPort = target.port > 0 ? target.port : AppConstants.Minimuxer.remotePairingPort
                debugLog("[WirelessPairViewModel] confirmSelection -> Connecting to target '\(target.name)' at \(targetIp):\(targetPort)")
                triggerPairing(targetIp: targetIp, targetPort: targetPort, targetName: target.name)
            case .configuredFallback:
                let fallback = fallbackConfigEndpoint
                debugLog("[WirelessPairViewModel] confirmSelection -> Connecting to configured fallback at \(fallback.ip):\(fallback.port)")
                triggerPairing(targetIp: fallback.ip, targetPort: fallback.port, targetName: "configured_host", usesLocalTransport: ConnectionConfig.shared.useLocalVPN)
            }
        } else {
            debugLog("[WirelessPairViewModel] confirmSelection -> Starting server advertising (selectedInterfaceId=\(selectedServerInterfaceId ?? "none"))")
            startPairing()
        }
    }
    
    private func resolveEndpoint(for service: DiscoveredService) async -> (ipv4: String?, ipv6: String?, port: UInt16) {
        debugLog("[WirelessPairViewModel] resolveEndpoint() starting for '\(service.name)' (\(service.type))...")
        return await withCheckedContinuation { continuation in
            let isTCP = service.type.contains("_tcp")
            let params = isTCP ? NWParameters.tcp : NWParameters.udp
            params.includePeerToPeer = true
            
            let conn = NWConnection(to: service.result.endpoint, using: params)
            let lock = NSLock()
            var didResume = false
            
            let resumeOnce: ((ipv4: String?, ipv6: String?, port: UInt16)) -> Void = { result in
                lock.withLock {
                    guard !didResume else { return }
                    didResume = true
                    conn.cancel()
                    debugLog("[WirelessPairViewModel] resolveEndpoint() resolved '\(service.name)': v4=\(result.ipv4 ?? "none"), v6=\(result.ipv6 ?? "none"), port=\(result.port)")
                    continuation.resume(returning: result)
                }
            }
            
            conn.pathUpdateHandler = { path in
                if path.status == .satisfied, let remote = path.remoteEndpoint {
                    var resolvedHost = ""
                    var portVal: UInt16 = 0
                    
                    switch remote {
                    case .hostPort(let host, let port):
                        resolvedHost = "\(host)".strippingInterfaceScope
                        portVal = port.rawValue
                    case .service(let sName, _, let sDomain, _):
                        let cleanDomain = sDomain.isEmpty ? "local" : (sDomain.hasSuffix(".") ? String(sDomain.dropLast()) : sDomain)
                        resolvedHost = "\(sName).\(cleanDomain)"
                        if let localEndpoint = path.localEndpoint, case .hostPort(_, let p) = localEndpoint {
                            portVal = p.rawValue
                        }
                    default:
                        resolvedHost = service.name
                    }
                    
                    guard portVal > 0 else { return }
                    let ips = BonjourDiscoveryManager.resolveHostToIPs(resolvedHost)
                    let v4 = ips.first(where: { !$0.contains(":") && $0 != "0.0.0.0" })
                        ?? (!resolvedHost.contains(":") && resolvedHost.filter({ $0 == "." }).count == 3 ? resolvedHost : nil)
                    let v6 = ips.first(where: { $0.contains(":") })
                        ?? (resolvedHost.contains(":") ? resolvedHost : nil)
                    
                    resumeOnce((v4, v6, portVal))
                }
            }
            
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready, .waiting:
                    guard let remote = conn.currentPath?.remoteEndpoint else { return }
                    var resolvedHost = ""
                    var portVal: UInt16 = 0
                    
                    switch remote {
                    case .hostPort(let host, let port):
                        resolvedHost = "\(host)".strippingInterfaceScope
                        portVal = port.rawValue
                    case .service(let sName, _, let sDomain, _):
                        let cleanDomain = sDomain.isEmpty ? "local" : (sDomain.hasSuffix(".") ? String(sDomain.dropLast()) : sDomain)
                        resolvedHost = "\(sName).\(cleanDomain)"
                        if let localEndpoint = conn.currentPath?.localEndpoint, case .hostPort(_, let p) = localEndpoint {
                            portVal = p.rawValue
                        }
                    default:
                        resolvedHost = service.name
                    }
                    
                    guard portVal > 0 else { return }
                    let ips = BonjourDiscoveryManager.resolveHostToIPs(resolvedHost)
                    let v4 = ips.first(where: { !$0.contains(":") && $0 != "0.0.0.0" })
                        ?? (!resolvedHost.contains(":") && resolvedHost.filter({ $0 == "." }).count == 3 ? resolvedHost : nil)
                    let v6 = ips.first(where: { $0.contains(":") })
                        ?? (resolvedHost.contains(":") ? resolvedHost : nil)
                    
                    resumeOnce((v4, v6, portVal))
                case .failed:
                    debugLog("[WirelessPairViewModel] resolveEndpoint() NWConnection state .failed for '\(service.name)'")
                    resumeOnce((nil, nil, 0))
                default:
                    break
                }
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                debugLog("[WirelessPairViewModel] resolveEndpoint() timeout (2.0s) reached for '\(service.name)'")
                resumeOnce((nil, nil, 0))
            }
            
            conn.start(queue: .global(qos: .userInitiated))
        }
    }
    
    func startDiscovery() {
        discoveryTask?.cancel()
        isScanning = true
        discoveredTargets.removeAll()
        
        discoveryTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            debugLog("[WirelessPairViewModel] startDiscovery() one-shot pass starting for types: \(self.pairingServiceTypes)")
            
            self.bonjour.discoverInstances(ofTypes: self.pairingServiceTypes, inDomain: "local.", clearExisting: true)
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else {
                debugLog("[WirelessPairViewModel] startDiscovery() Task was cancelled before instance snapshot")
                return
            }
            
            let instancesSnapshot = self.bonjour.instances
            debugLog("[WirelessPairViewModel] one-shot: gathered \(instancesSnapshot.count) Bonjour instances from BonjourDiscoveryManager:")
            for s in instancesSnapshot {
                debugLog("[WirelessPairViewModel]  -> instance: name='\(s.name)', type='\(s.type)', domain='\(s.domain)', id='\(s.id)'")
            }
            
            self.bonjour.stopInstanceSearch()
            debugLog("[WirelessPairViewModel] Bonjour search stopped, resolving \(instancesSnapshot.count) endpoints in parallel...")
            
            var finalTargets: [WirelessPairTarget] = []
            await withTaskGroup(of: WirelessPairTarget.self) { group in
                for service in instancesSnapshot {
                    group.addTask {
                        let (ipv4, ipv6, port) = await self.resolveEndpoint(for: service)
                        return WirelessPairTarget(service: service, ipv4: ipv4, ipv6: ipv6, port: port)
                    }
                }
                for await target in group {
                    finalTargets.append(target)
                }
            }
            
            guard !Task.isCancelled else {
                debugLog("[WirelessPairViewModel] startDiscovery() Task was cancelled during endpoint resolution")
                return
            }
            finalTargets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.discoveredTargets = finalTargets
            self.isScanning = false
            debugLog("[WirelessPairViewModel] one-shot pass complete: \(self.discoveredTargets.count) targets ready:")
            for t in self.discoveredTargets {
                debugLog("[WirelessPairViewModel]  -> Target: '\(t.name)' [\(t.rawType)] - IPv4: \(t.ipv4 ?? "none"), IPv6: \(t.ipv6 ?? "none"), Port: \(t.port)")
            }
        }
    }
    
    func stopDiscovery() {
        debugLog("[WirelessPairViewModel] stopDiscovery() invoked")
        discoveryTask?.cancel()
        discoveryTask = nil
        isScanning = false
        bonjour.stopInstanceSearch()
    }
    
    func startLocalPairingWithInstructions() {
        guard !isSavingLockdown else { return }
        Task {
            await PairingActivityController.shared.requestNotificationPermission()
            if isAdvertising, port != nil { showSelfPairingInstructions = true; return }
            showInstructionsWhenReady = true
            startPairing()
        }
    }

    func startPairing() {
        guard pairingTask == nil, !isAdvertising, !isSavingLockdown else { return }
        let docsPath = FileManager.default.documentsDirectory.path
        PairingActivityController.shared.start { [weak self] in
            self?.stopPairing()
            self?.errorMessage = NSLocalizedString("iOS ended the background session. Return to zLoader and start Self-Pairing again.", comment: "")
        }
        isAdvertising = true
        pairedDevice = nil
        confirmationMessage = nil
        pinCode = nil
        errorMessage = nil
        serviceID = nil
        port = nil
        statusText = NSLocalizedString("Starting Pairing Server…", comment: "")
        subStatusText = NSLocalizedString("When the server is ready, open Settings → Privacy & Security → Developer Mode.", comment: "")
        pairingTask = Task { @MainActor in
            do {
                let operation = {
                    try Task.checkCancellation()
                    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MinimuxerPairedDevice, Error>) in
                        wirelessPairing.start(outPath: docsPath, resolveFileName: { name, model in
                            Self.pairingFileName(for: name, model: model)
                        }, completion: { continuation.resume(with: $0) })
                    }
                }
                let device = try await (isSelfPairing ? ZLoaderTransport.withLease(operation) : operation())
                pairingTask = nil
                guard !Task.isCancelled else { return }
                isAdvertising = false
                showInstructionsWhenReady = false
                pinCode = nil
                serviceID = nil
                port = nil
                wirelessPairing.stop()
                acceptPairedDevice(device)
            } catch {
                pairingTask = nil
                guard !Task.isCancelled else { return }
                isAdvertising = false
                showInstructionsWhenReady = false
                errorMessage = error.localizedDescription
                statusText = NSLocalizedString("Pairing Failed", comment: "")
                PairingActivityController.shared.finish(status: "Pairing Failed", success: false)
            }
        }
    }

    func stopPairing() {
        debugLog("[WirelessPairViewModel] stopPairing() stopping advertisement and tearing down session")
        showInstructionsWhenReady = false
        showSelfPairingInstructions = false
        pairingTask?.cancel()
        wirelessPairing.stop()
        PairingActivityController.shared.finish(status: "Pairing Stopped", success: false)
        
        isAdvertising = false
        statusText = NSLocalizedString("Ready to pair", comment: "")
        subStatusText = NSLocalizedString("Tap Start to advertise this device on the local network.", comment: "")
        pinCode = nil
        errorMessage = nil
        serviceID = nil
        port = nil
    }
    
    func triggerPairing(
        targetIp: String,
        targetPort: UInt16,
        targetName: String? = nil,
        usesLocalTransport: Bool = false,
        completion: ((Result<MinimuxerPairedDevice, Swift.Error>) -> Void)? = nil
    ) {
        guard pairingTask == nil else { return }
        let docsPath = FileManager.default.documentsDirectory.path
        debugLog("[WirelessPairViewModel] triggerPairing() initiating handshake to \(targetIp):\(targetPort), base path: '\(docsPath)'")
        isAdvertising = true
        pinCode = nil
        errorMessage = nil
        serviceID = nil
        port = nil
        statusText = NSLocalizedString("Connecting to device...", comment: "")
        subStatusText = "Initiating pairing handshake on \(targetIp):\(targetPort)..."
        
        pairingTask = Task { @MainActor in
            let operation = {
                try Task.checkCancellation()
                let device: MinimuxerPairedDevice = try await withCheckedThrowingContinuation { continuation in
                    wirelessPairing.trigger(
                        targetIp: targetIp,
                        targetPort: targetPort,
                        outPath: docsPath,
                        resolveFileName: { name, model in
                            Self.pairingFileName(for: name.isEmpty ? targetName : name, model: model)
                        },
                        completion: { continuation.resume(with: $0) }
                    )
                }
                try Task.checkCancellation()
                return device
            }
            let result: Result<MinimuxerPairedDevice, Swift.Error>
            do {
                // Hold the local tunnel until the handshake really finishes, including cancellation.
                let device = try await usesLocalTransport
                    ? ZLoaderTransport.withLease(operation)
                    : operation()
                result = .success(device)
            } catch {
                result = .failure(error)
            }
            pairingTask = nil
            guard !Task.isCancelled else { return }
            isAdvertising = false
            pinCode = nil
            serviceID = nil
            port = nil
            switch result {
            case .success(let device):
                acceptPairedDevice(device)
            case .failure(let error):
                errorMessage = error.localizedDescription
                statusText = NSLocalizedString("Pairing Failed", comment: "")
                subStatusText = "An error occurred during pairing: \(error.localizedDescription)"
            }
            completion?(result)
        }
    }
    

    private func acceptPairedDevice(_ device: MinimuxerPairedDevice) {
        let url = URL(fileURLWithPath: device.pairingFilePath)
        guard isSelfPairing else {
            pairedDevice = device
            statusText = NSLocalizedString("Pairing Complete", comment: "")
            subStatusText = NSLocalizedString("Export the pairing file for the paired device.", comment: "")
            confirmationMessage = nil
            PairingActivityController.shared.finish(status: "Pairing Complete", success: true)
            return
        }
        do {
            try PairingFileManager.shared.importPairingFile(from: url)
            pairedDevice = device
            try onPairingFileReady?(url)
            statusText = NSLocalizedString("Pairing Complete", comment: "")
            subStatusText = NSLocalizedString("The generated file was imported directly into zLoader.", comment: "")
            confirmationMessage = NSLocalizedString("Your remote pairing file is saved in zLoader. Lockdown files can be imported separately from your computer.", comment: "")
            PairingActivityController.shared.finish(status: NSLocalizedString("Pairing Complete", comment: ""), success: true)
            Task {
                do {
                    let (content, parsed) = try PairingFileManager.shared.inspectPairingFile(from: url)
                    try await minimuxerStart(content, preferred: parsed.mode)
                } catch {
                    confirmationMessage = NSLocalizedString("Pairing File Saved, Activation Failed: ", comment: "") + error.localizedDescription
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            statusText = NSLocalizedString("Pairing File Import Failed", comment: "")
            PairingActivityController.shared.finish(status: "Import Failed", success: false)
        }
    }

    nonisolated static func pairingFileName(for deviceName: String? = nil, model: String? = nil) -> String {
        let namePart = deviceName ?? ""
        let modelPart = model ?? ""
        let combined = [namePart, modelPart].filter { !$0.isEmpty }.joined(separator: "_")
        if !combined.isEmpty {
            let spaceReplaced = combined
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
            let sanitized = spaceReplaced.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
            let finalName = sanitized.isEmpty ? "device" : sanitized
            return "\(finalName)\(AppConstants.Minimuxer.rpPairingFileSuffix)"
        }
        return AppConstants.Minimuxer.defaultRPPairingFileName
    }

    private func pairingFilePath(for deviceName: String? = nil, model: String? = nil) -> String {
        let docs = FileManager.default.documentsDirectory
        let fileName = Self.pairingFileName(for: deviceName, model: model)
        return docs.appendingPathComponent(fileName).path
    }
}
