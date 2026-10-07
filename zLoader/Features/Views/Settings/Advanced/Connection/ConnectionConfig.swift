//
//  ConnectionConfig.swift
//  ZLoader
//
//  Created by Magesh K on 02/03/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import Combine

final class ConnectionConfig: ObservableObject {
    static let shared = ConnectionConfig()

    // yeah we dont use default coz we expect auto discovery to find it
    private static var defaultOverrideIP: String { "" }     
    private static var defaultRemoteServerIP: String { AppConstants.Connection.defaultRemoteServerIP }

    @Published var tunnelIfaceIp: String?
    @Published var tunnelIfaceSubnetMask: String?
    @Published var tunnelPeerIp: String?
    @Published var tunnelPeerSubnetMask: String?
    @Published var tunnelPeerReachable: Bool = false
    @Published var overrideTunnelPeerIp: String = overrideIPStorage {
        didSet { Self.overrideIPStorage = overrideTunnelPeerIp }
    }
    @Published var overrideTunnelPeerReachable: Bool = false

    @Published var remoteServerIp: String = remoteServerIPStorage {
        didSet { Self.remoteServerIPStorage = remoteServerIp }
    }
    @Published var remotePeerIp: String?
    @Published var remoteReachable: Bool = false

    @Published var useLocalVPN: Bool = useLocalVPNStorage {
        didSet { Self.useLocalVPNStorage = useLocalVPN }
    }

    private static var overrideIPStorage: String {
        get { UserDefaults.standard.tunnelOverridePeerIp ?? defaultOverrideIP }
        set { UserDefaults.standard.tunnelOverridePeerIp = newValue }
    }

    private static var remoteServerIPStorage: String {
        get { UserDefaults.standard.remoteServerIp ?? defaultRemoteServerIP }
        set { UserDefaults.standard.remoteServerIp = newValue }
    }

    private static var useLocalVPNStorage: Bool {
        get { UserDefaults.standard.useLocalVPN }
        set { UserDefaults.standard.useLocalVPN = newValue }
    }

    var effectiveTunnelPeerIP: String {
        let override = overrideTunnelPeerIp.trimmingCharacters(in: .whitespacesAndNewlines)
        return override.isEmpty && useLocalVPN ? "10.7.0.1" : override
    }

    func isEffectivePeerReachable(discovered: Bool, override: Bool) -> Bool {
        // Without an explicit override, accept the discovered routed peer too.
        // External local tunnels need not use External Local VPN Tunnel's default 10.7.0.1.
        if overrideTunnelPeerIp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return discovered || override
        }
        return override
    }

    var tunnelPeerActive: ActiveState {
        isEffectivePeerReachable(discovered: tunnelPeerReachable, override: overrideTunnelPeerReachable) ? .yes : .no
    }
    var overrideTunnelPeerActive: ActiveState { overrideTunnelPeerReachable ? .yes : .no }
    var remoteActive: ActiveState { remoteReachable ? .yes : .no }

    var formattedTunnelIface: String? {
        guard let ip = tunnelIfaceIp, !ip.isEmpty else { return nil }
        if let mask = tunnelIfaceSubnetMask, let cidr = Self.cidrPrefix(from: mask) {
            return "\(ip)/\(cidr)"
        }
        return ip
    }

    var formattedTunnelPeer: String? {
        guard let ip = tunnelPeerIp, !ip.isEmpty else { return nil }
        if let mask = tunnelPeerSubnetMask, let cidr = Self.cidrPrefix(from: mask) {
            return "\(ip)/\(cidr)"
        }
        return ip
    }

    static func cidrPrefix(from subnetMask: String) -> Int? {
        let octets = subnetMask.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return nil }
        return octets.reduce(0) { $0 + $1.nonzeroBitCount }
    }
}

extension UserDefaults {
    @objc var tunnelOverridePeerIp: String? {
        get { self.string(forKey: "TunnelOverridePeerIp") }
        set { self.set(newValue, forKey: "TunnelOverridePeerIp") }
    }

    @objc var remoteServerIp: String? {
        get { self.string(forKey: "RemoteServerIp") }
        set { self.set(newValue, forKey: "RemoteServerIp") }
    }

}
