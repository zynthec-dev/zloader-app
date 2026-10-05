//
//  MinimuxerWrapper.swift
//
//  Created by Magesh K on 22/02/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import Network
import Minimuxer
import MinimuxerCommon
import Combine

public var selectedGatewayBackendCache: GatewayBackend = .idevice
public var remotePairingPortCache: UInt16 = AppConstants.Minimuxer.remotePairingPort
public var deviceProbeTimeoutCache: Int = AppConstants.Minimuxer.defaultTCPProbeTimeoutMs

public func syncMinimuxerBackendFromUserDefaults() {
    let raw = UserDefaults.standard.minimuxerGatewayBackend
    selectedGatewayBackendCache = GatewayBackend(rawValue: raw) ?? .idevice

    let overridePort = UserDefaults.standard.remotePairingPortOverride
    if overridePort > 0 && overridePort <= 65535 {
        remotePairingPortCache = UInt16(overridePort)
    } else {
        let lastDiscovered = UserDefaults.standard.lastDiscoveredRemotePairingPort
        if lastDiscovered > 0 && lastDiscovered <= 65535 {
            remotePairingPortCache = UInt16(lastDiscovered)
        } else {
            remotePairingPortCache = AppConstants.Minimuxer.remotePairingPort
        }
    }

    let overrideTimeout = UserDefaults.standard.deviceProbeTimeoutOverride
    if overrideTimeout > 0 {
        deviceProbeTimeoutCache = overrideTimeout
    } else {
        deviceProbeTimeoutCache = AppConstants.Minimuxer.defaultTCPProbeTimeoutMs
    }

    minimuxer.set(MinimuxerParams(
        backend: selectedGatewayBackendCache,
        remotePairingPort: remotePairingPortCache,
        deviceProbeTimeout: deviceProbeTimeoutCache
    ))
}

var minimuxer: any MinimuxerFacade {
    Minimuxer.shared
}

func minimuxerPairingProtocol() -> PairingProtocol {
    minimuxer.core.pairingFileType
}

var ddiMountPath: String {
    FileManager.default.documentsDirectory.absoluteString
}

private func resolveDiscoveredRemotePairingPort() async -> UInt16? {
    guard UserDefaults.standard.isAutoRetryRemotePairingPortEnabled else {
        return nil
    }
    let overridePort = UserDefaults.standard.remotePairingPortOverride
    if overridePort > 0 && overridePort <= 65535 {
        return UInt16(overridePort)
    }
    if let resolved = await BonjourDiscoveryManager.resolveFirstService(
        ofType: AppConstants.Minimuxer.remotePairingDaemonServiceType,
        timeout: AppConstants.Bonjour.defaultDiscoveryTimeout,
        isPreferredCandidate: { res in
            res.interfaces.contains { $0.name == "lo0" || $0.name.hasPrefix("lo") }
        }
    ) {
        debugLog("[zLoader] Discovered RemotePairing port via Bonjour: \(resolved.port)")
        UserDefaults.standard.lastDiscoveredRemotePairingPort = Int(resolved.port)
        return resolved.port
    }
    return nil
}

private var lastRemotePairingPortResolveTime: Date = .distantPast
private var activeRemotePairingPortResolveTask: Task<UInt16?, Never>?

private func resolveDiscoveredRemotePairingPortThrottled() async -> UInt16? {
    let overridePort = UserDefaults.standard.remotePairingPortOverride
    if overridePort > 0 && overridePort <= 65535 {
        return UInt16(overridePort)
    }

    let now = Date()
    guard now.timeIntervalSince(lastRemotePairingPortResolveTime) > 5.0 else {
        return nil
    }

    if let inFlight = activeRemotePairingPortResolveTask {
        return await inFlight.value
    }

    let task = Task<UInt16?, Never> {
        defer {
            activeRemotePairingPortResolveTask = nil
            lastRemotePairingPortResolveTime = Date()
        }
        return await resolveDiscoveredRemotePairingPort()
    }
    activeRemotePairingPortResolveTask = task
    return await task.value
}

private func isRetriableRemotePairingError(_ error: Error) -> Bool {
    if let minErr = error as? MinimuxerError {
        switch minErr {
        case .noDevice, .notReachable:
            return true
        default:
            return false
        }
    }
    if let opErr = error as? OperationError {
        switch opErr {
        case .noDevice, .notReachable, .unknownUDID:
            return true
        default:
            return false
        }
    }
    return true
}

private func withRemotePairingRetry<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch {
        guard UserDefaults.standard.isAutoRetryRemotePairingPortEnabled,
              minimuxer.gateway.pairingFileType == .rppairing,
              isRetriableRemotePairingError(error) else 
        {
            throw error
        }

        if let newPort = await resolveDiscoveredRemotePairingPortThrottled(), newPort != remotePairingPortCache {
            debugLog("[zLoader] Operation failed with retriable error (\(error)), updating RemotePairing port from \(remotePairingPortCache) -> \(newPort) and retrying...")
            remotePairingPortCache = newPort
            minimuxer.set(MinimuxerParams(remotePairingPort: newPort))
            return try await operation()
        }
        throw error
    }
}

public var minimuxerStatusPublisher: AnyPublisher<Result<Bool, Error>, Never> {
    minimuxer.core.statusPublisher
        .map { result in
            result.mapError { $0 as Error }
        }
        .eraseToAnyPublisher()
}

func bindConnectionConfig() async {
    defer { debugLog("[zLoader] bindTunnelConfig() completed") }

    debugLog("[zLoader] bindTunnelConfig() invoked")
    let config = ConnectionConfig.shared
    let configBinding = ConnectionConfigBinding(
        setTunnelIfaceIp: { value in Task { @MainActor in config.tunnelIfaceIp = value } },
        setTunnelPeerIp: { value in Task { @MainActor in config.tunnelPeerIp = value } },
        setTunnelPeerSubnetMask: { value in Task { @MainActor in config.tunnelPeerSubnetMask = value } },
        setTunnelPeerReachable: { value in Task { @MainActor in config.tunnelPeerReachable = value } },
        setTunnelIfaceSubnetMask: { value in Task { @MainActor in config.tunnelIfaceSubnetMask = value } },
        getRemoteServerIp: { config.remoteServerIp },
        setRemoteReachable: { value in Task { @MainActor in config.remoteReachable = value } },
        getOverrideTunnelPeerIp: { config.overrideTunnelPeerIp },
        setOverrideTunnelPeerReachable: { value in Task { @MainActor in config.overrideTunnelPeerReachable = value } },
        getConnectionMode: { config.useLocalVPN ? .localVPN : .remoteServer },
        resolveServicePort: { failed in
            guard UserDefaults.standard.isAutoRetryRemotePairingPortEnabled else {
                return failed
            }
            switch failed.protocolType {
                case .rppairing:
                    if let discovered = await resolveDiscoveredRemotePairingPort() {
                        remotePairingPortCache = discovered
                        minimuxer.set(MinimuxerParams(remotePairingPort: discovered))
                        return ServicePort(protocolType: .rppairing, port: discovered)
                    }
                    return failed
                case .lockdown:
                    return ServicePort(protocolType: .lockdown, port: AppConstants.Minimuxer.lockdowndPort)
                case .unknown:
                    return failed
            }
        }
    )
    await minimuxer.core.bindConnectionConfig(configBinding)
}

func getDeviceConnectionMode() async -> DeviceConnectionMode {
    return await minimuxer.core.getConnectionMode()
}

public func isMinimuxerReady() async -> Result<Bool, MinimuxerError> {
    let isEnabled = CellularRefreshManager.shared.isEnabled
    return await minimuxer.core.isReady(withNetworkCheck: !isEnabled)
}

public func ensureMinimuxerReady() async throws {
    try await ZLoaderTransport.withLease {
        await minimuxer.network.refreshEndpoint()
        try await withRemotePairingRetry {
            switch await isMinimuxerReady() {
            case .success(true): return
            case .success(false): throw OperationError.noConnection(reason: "Device transport is not ready.")
            case .failure(let error): throw error.asOperationError
            }
        }
    }
}

extension MinimuxerError {
    var asOperationError: OperationError {
        switch self {
        case .noDevice(let reason):             return .noDevice(reason: reason)
        case .noConnection(let reason):         return .noConnection(reason: reason)
        case .notReachable(let reason):         return .notReachable(reason: reason)
        case .noVPN(let reason):                return .noVPN(reason: reason)
        case .invalidVPN(let reason):           return .invalidVPN(reason: reason)
        case .invalidPairing(_, let reason):    return .invalidPairingFile(reason: reason)
        case .notStarted(let reason):           return .minimuxerNotStarted(reason: reason)
        case .pairingNotLoaded(let reason):            return .pairingNotComplete(reason: reason)
        case .connectionModeNotConfigured(let reason): return .invalidParameters(reason)
        default:                                       return .invalidParameters(self.description)
        }
    }
}

func reinitializePairingData(pairingFile: String) async throws {
    defer { debugLog("[zLoader] reinitializePairingData(pairingFile) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] reinitializePairingData(pairingFile) is no-op on simulator")
    #else
    debugLog("[zLoader] reinitializePairingData(pairingFile) invoked")
    try await withRemotePairingRetry {
        try await minimuxer.core.reinitializePairingData(pairingFile: pairingFile)
    }
    #endif
}

func minimuxerStart(_ pairingFile: String, preferred: PairingProtocol? = nil) async throws {
    defer { debugLog("[zLoader] minimuxerStart(pairingFile) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] minimuxerStart(pairingFile) is no-op on simulator")
    await bindConnectionConfig()
    await minimuxer.network.start()
    #else
    await bindConnectionConfig()
    debugLog("[zLoader] minimuxerStart(pairingFile) invoked")
    try await withRemotePairingRetry {
        try await minimuxer.core.start(pairingFile: pairingFile, mountPath: ddiMountPath, preferred: preferred)
    }
    #endif
}

func minimuxerStop() async throws {
    defer { debugLog("[zLoader] minimuxerStop() completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] minimuxerStop() is no-op on simulator")
    #else
    debugLog("[zLoader] minimuxerStop() invoked")
    try await minimuxer.core.stop()
    #endif
}

private func withDeviceTransport<T>(_ operation: () async throws -> T) async throws -> T {
    try await ZLoaderTransport.withLease {
        try await withRemotePairingRetry(operation)
    }
}

func installProvisioningProfiles(_ profileData: Data) async throws {
    defer { debugLog("[zLoader] installProvisioningProfiles(profileData) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] installProvisioningProfiles(profileData) is no-op on simulator")
    #else
    debugLog("[zLoader] installProvisioningProfiles(profileData) invoked")
    try await withDeviceTransport {
        try await minimuxer.core.installProvisioningProfile(profile: profileData)
    }
    #endif
}

func removeProvisioningProfile(_ id: String) async throws {
    defer { debugLog("[zLoader] removeProvisioningProfile(id) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] removeProvisioningProfile(id) is no-op on simulator")
    #else
    debugLog("[zLoader] removeProvisioningProfile(id) invoked")
    try await withDeviceTransport {
        try await minimuxer.core.removeProvisioningProfile(id: id)
    }
    #endif
}

func removeApp(_ bundleId: String) async throws {
    defer { debugLog("[zLoader] removeApp(bundleId) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] removeApp(bundleId) is no-op on simulator")
    #else
    debugLog("[zLoader] removeApp(bundleId) invoked")
    try await withDeviceTransport {
        try await minimuxer.core.removeApp(bundleId: bundleId)
    }
    #endif
}

func sendIpaAfc(_ bundleId: String, _ rawBytes: Data) async throws {
    defer { debugLog("[zLoader] sendIpaAfc(bundleId, rawBytes) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] sendIpaAfc(bundleId, rawBytes) is no-op on simulator")
    #else
    debugLog("[zLoader] sendIpaAfc(bundleId, rawBytes) invoked")
    try await withDeviceTransport {
        try await minimuxer.core.sendIpaAfc(bundleId: bundleId, ipaBytes: rawBytes)
    }
    #endif
}

func sendAppBundleAfc(_ bundleId: String, at appURL: URL) async throws {
    defer { debugLog("[zLoader] sendAppBundleAfc(bundleId, appURL) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] sendAppBundleAfc(bundleId, appURL) is no-op on simulator")
    #else
    debugLog("[zLoader] sendAppBundleAfc(bundleId, appURL) invoked")
    try await withDeviceTransport {
        try await minimuxer.core.sendAppBundleAfc(bundleId: bundleId, appURL: appURL)
    }
    #endif
}

func installIPA(_ bundleId: String) async throws {
    defer { debugLog("[zLoader] installIPA(bundleId) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] installIPA(bundleId) is no-op on simulator")
    #else
    debugLog("[zLoader] installIPA(bundleId) invoked")
    try await withDeviceTransport {
        try await minimuxer.core.installIpa(bundleId: bundleId)
    }
    #endif
}

func installAppBundle(_ bundleId: String, appName: String) async throws {
    defer { debugLog("[zLoader] installAppBundle(bundleId, appName) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] installAppBundle(bundleId, appName) is no-op on simulator")
    #else
    debugLog("[zLoader] installAppBundle(bundleId, appName) invoked")
    try await withDeviceTransport {
        try await minimuxer.core.installAppBundle(bundleId: bundleId, appName: appName)
    }
    #endif
}

@discardableResult
func fetchUDID(forceLive: Bool = false) async throws -> String {
    defer { debugLog("[zLoader] fetchUDID() completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] fetchUDID() is no-op on simulator")
    return "00008030-001234567890ABCD"
    
    #else
    if !forceLive, let cachedUDID = Keychain.shared.deviceUDID, !cachedUDID.isEmpty {
        debugLog("[zLoader] fetchUDID() returning cached UDID from Keychain: \(cachedUDID)")
        return cachedUDID
    }
    debugLog("[zLoader] fetchUDID() invoked (forceLive: \(forceLive))")
    return try await withDeviceTransport {
        let udid = try await minimuxer.core.fetchUDID()
        guard !udid.isEmpty else {
            throw OperationError.unknownUDID(reason: "Minimuxer returned empty UDID.")
        }
        Keychain.shared.deviceUDID = udid
        return udid
    }
    #endif
}

@discardableResult
func safeFetchUDID(forceLive: Bool = false) async throws -> String {
    try await ensureMinimuxerReady()
    return try await fetchUDID(forceLive: forceLive)
}

func debugApp(_ appId: String) async throws {
    defer { debugLog("[zLoader] debugApp(appId) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] debugApp(appId) is no-op on simulator")
    #else
    debugLog("[zLoader] debugApp(appId) invoked")
    try await withDeviceTransport {
        try await minimuxer.core.debugApp(appId: appId)
    }
    #endif
}

func safeDebugApp(_ appId: String) async throws {
    try await ensureMinimuxerReady()
    try await debugApp(appId)
}

func attachDebugger(_ pid: UInt32) async throws {
    defer { debugLog("[zLoader] attachDebugger(pid) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] attachDebugger(pid) is no-op on simulator")
    #else
    debugLog("[zLoader] attachDebugger(pid) invoked")
    try await withDeviceTransport {
        try await minimuxer.core.attachDebugger(pid: pid)
    }
    #endif
}

func safeAttachDebugger(_ pid: UInt32) async throws {
    try await ensureMinimuxerReady()
    try await attachDebugger(pid)
}

func dumpProfiles(_ docsPath: String, mode: ProfileDumpMode = .zip) async throws -> String {
    defer { debugLog("[zLoader] dumpProfiles(docsPath) completed") }
    #if targetEnvironment(simulator)
    debugLog("[zLoader] dumpProfiles(docsPath) is no-op on simulator")
    return ""
    #else
    debugLog("[zLoader] dumpProfiles(docsPath) invoked")
    return try await withDeviceTransport {
        try await minimuxer.core.dumpProfiles(docsPath: docsPath, mode: mode)
    }
    #endif
}

func safeDumpProfiles(_ docsPath: String, mode: ProfileDumpMode = .zip) async throws -> String {
    try await ensureMinimuxerReady()
    return try await dumpProfiles(docsPath, mode: mode)
}

func minimuxerSetLogging(_ enabled: Bool) {
    defer { debugLog("[zLoader] minimuxerSetLogging(enabled) completed") }
    debugLog("[zLoader] minimuxerSetLogging(enabled) invoked")
    #if !targetEnvironment(simulator)
    minimuxer.core.setLogging(enabled)
    #endif
}

public func minimuxerGetDeviceProbeTimeout() -> Int {
    #if targetEnvironment(simulator)
    return deviceProbeTimeoutCache
    #else
    return minimuxer.core.deviceProbeTimeout
    #endif
}

public func minimuxerSetDeviceProbeTimeout(_ timeoutMs: Int) {
    defer { debugLog("[zLoader] minimuxerSetDeviceProbeTimeout(\(timeoutMs)) completed") }
    debugLog("[zLoader] minimuxerSetDeviceProbeTimeout(\(timeoutMs)) invoked")
    deviceProbeTimeoutCache = timeoutMs
    UserDefaults.standard.deviceProbeTimeoutOverride = (timeoutMs == AppConstants.Minimuxer.defaultTCPProbeTimeoutMs) ? 0 : timeoutMs
    #if !targetEnvironment(simulator)
    minimuxer.set(MinimuxerParams(deviceProbeTimeout: timeoutMs))
    #endif
}

extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

func minimuxerSwitchPairingProtocol(to proto: PairingProtocol) async throws {
    defer { debugLog("[zLoader] minimuxerSwitchPairingProtocol(.\(proto)) completed") }
    debugLog("[zLoader] minimuxerSwitchPairingProtocol(.\(proto)) invoked")
    PairingFileManager.shared.persistedActiveProtocol = proto
    #if !targetEnvironment(simulator)
    try await withRemotePairingRetry {
        debugLog("[zLoader] switchPairingProtocol(to: \(proto.rawValue)) entered")
        guard let pf = PairingFileManager.shared.fetchPairingFile(for: proto) else {
            throw MinimuxerError.pairingNotLoaded("Missing pairing file for \(proto.rawValue)")
        }
        try await minimuxerStop()
        try await AppBootManager.shared.startMinimuxer(pairingFile: pf)
    }
    #endif
}

public struct MinimuxerPairedDevice: Codable, Sendable {
    public let name: String
    public let model: String
    public let pairingFilePath: String
    
    public init(name: String, model: String, pairingFilePath: String) {
        self.name = name
        self.model = model
        self.pairingFilePath = pairingFilePath
    }
}

public final class WirelessPairWrapper {
    public static let shared = WirelessPairWrapper()
    
    private init() {}
    
    public var onPinReceived: ((String) -> Void)? {
        get {
            #if !targetEnvironment(simulator)
            return minimuxer.wirelessPair.onPinReceived
            #else
            return nil
            #endif
        }
        set {
            #if !targetEnvironment(simulator)
            minimuxer.wirelessPair.onPinReceived = newValue
            #endif
        }
    }
    
    public var onReadyToPair: ((String, Int) -> Void)? {
        get {
            #if !targetEnvironment(simulator)
            return minimuxer.wirelessPair.onReadyToPair
            #else
            return nil
            #endif
        }
        set {
            #if !targetEnvironment(simulator)
            minimuxer.wirelessPair.onReadyToPair = newValue
            #endif
        }
    }
    
    public var onRequestPin: ((@escaping (String) -> Void) -> Void)? {
        get {
            #if !targetEnvironment(simulator)
            return minimuxer.wirelessPair.onRequestPin
            #else
            return nil
            #endif
        }
        set {
            #if !targetEnvironment(simulator)
            minimuxer.wirelessPair.onRequestPin = newValue
            #endif
        }
    }
    
    public func start(
        outPath: String,
        resolveFileName: (@Sendable (String, String) -> String)? = nil,
        completion: @escaping (Result<MinimuxerPairedDevice, Error>) -> Void
    ) {
        debugLog("[WirelessPairWrapper] start(outPath: '\(outPath)')")
        #if !targetEnvironment(simulator)
        minimuxer.wirelessPair.start(outPath: outPath, resolveFileName: resolveFileName) { result in
            debugLog("[WirelessPairWrapper] start callback received: result=\(result)")
            switch result {
            case .success(let device):
                completion(.success(MinimuxerPairedDevice(
                    name: device.name,
                    model: device.model,
                    pairingFilePath: device.pairingFilePath
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        #else
        completion(.failure(OperationError.invalidParameters("Wireless pairing is not supported on simulator.")))
        #endif
    }

    public func trigger(
        targetIp: String,
        targetPort: UInt16,
        hostName: String = AppConstants.Minimuxer.defaultHostName,
        hostModel: String = AppConstants.Minimuxer.defaultHostModel,
        outPath: String,
        resolveFileName: (@Sendable (String, String) -> String)? = nil,
        completion: @escaping (Result<MinimuxerPairedDevice, Error>) -> Void
    ) {
        debugLog("[WirelessPairWrapper] trigger(targetIp: '\(targetIp)', targetPort: \(targetPort), hostName: '\(hostName)', hostModel: '\(hostModel)', outPath: '\(outPath)')")
        #if !targetEnvironment(simulator)
        minimuxer.wirelessPair.trigger(
            targetIp: targetIp,
            targetPort: targetPort,
            hostName: hostName,
            hostModel: hostModel,
            outPath: outPath,
            resolveFileName: resolveFileName
        ) { result in
            debugLog("[WirelessPairWrapper] trigger callback received: result=\(result)")
            switch result {
            case .success(let device):
                completion(.success(MinimuxerPairedDevice(
                    name: device.name,
                    model: device.model,
                    pairingFilePath: device.pairingFilePath
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        #else
        completion(.failure(OperationError.invalidParameters("Wireless pairing is not supported on simulator.")))
        #endif
    }
    
    public func stop() {
        debugLog("[WirelessPairWrapper] stop() invoked")
        #if !targetEnvironment(simulator)
        minimuxer.wirelessPair.stop()
        #endif
    }
}

let wirelessPairing = WirelessPairWrapper.shared
