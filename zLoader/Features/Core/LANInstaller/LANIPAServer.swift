import Foundation
import Network
import Security
import Darwin

/// All mutable connection/file state is confined to queue. Only an immutable IPA copy is served.
final class LANIPAServer: @unchecked Sendable {
    struct Status: Sendable { var url: URL?; var progress: Double = 0; var complete = false; var error: String? }
    private let queue = DispatchQueue(label: "com.zynthec.zLoader.LANInstaller")
    private var listener: NWListener?
    private var awaitingHeaders = Set<UUID>()
    private var connections: [UUID: NWConnection] = [:]
    private var identity: LANCertificate.ServerIdentity?
    private var base: URL?
    private var ipa: URL?
    private var size: UInt64 = 0
    private var manifest = Data()
    private var page = Data()
    private let changed: @Sendable (Status) -> Void
    init(changed: @escaping @Sendable (Status) -> Void) { self.changed = changed }
    static func wifiAddress() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor {
            defer { cursor = item.pointee.ifa_next }
            guard String(cString: item.pointee.ifa_name) == "en0", let address = item.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET), (item.pointee.ifa_flags & UInt32(IFF_UP)) != 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: host)
            }
        }
        return nil
    }
    func start(ipa: URL, ip: String, name: String, bundleID: String, version: String, authority: LANCertificate.Authority) {
        queue.async { [self] in
            stopOnQueue()
            do {
                self.ipa = ipa
                size = (try FileManager.default.attributesOfItem(atPath: ipa.path)[.size] as? NSNumber)?.uint64Value ?? 0
                guard size > 0 else { throw LANHTTP.Failure.badRequest }
                identity = try LANCertificate.identity(authority: authority, ip: ip, name: name)
                let tls = NWProtocolTLS.Options()
                guard let identity, let local = sec_identity_create(identity.identity) else { throw LANCertificate.Failure.crypto }
                sec_protocol_options_set_local_identity(tls.securityProtocolOptions, local)
                sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
                let parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
                parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host(ip), port: .any)
                parameters.requiredInterfaceType = .wifi
                parameters.allowLocalEndpointReuse = true
                let listener = try NWListener(using: parameters)
                self.listener = listener
                let token = UUID().uuidString.lowercased()
                listener.stateUpdateHandler = { [weak self, weak listener] state in
                    guard let self, let listener, self.listener === listener else { return }
                    switch state {
                    case .ready:
                        guard let port = listener.port, let url = URL(string: "https://\(ip):\(port.rawValue)/\(token)/") else { return }
                        do {
                            self.base = url
                            self.manifest = try LANHTTP.manifest(base: url, bundleID: bundleID, version: version, name: name)
                            self.page = LANHTTP.page(base: url, name: name)
                            self.changed(Status(url: url))
                        } catch { self.fail(error) }
                    case .failed(let error): self.fail(error)
                    default: break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
                listener.start(queue: queue)
            } catch { fail(error) }
        }
    }
    func stop() { queue.async { [self] in stopOnQueue(); changed(Status()) } }
    private func stopOnQueue() {
        listener?.stateUpdateHandler = nil; listener?.newConnectionHandler = nil; listener?.cancel(); listener = nil
        for connection in connections.values { connection.cancel() }
        connections.removeAll(); awaitingHeaders.removeAll(); identity?.remove(); identity = nil; base = nil
    }
    private func fail(_ error: Error) { stopOnQueue(); changed(Status(error: error.localizedDescription)) }
    private func close(_ id: UUID) { awaitingHeaders.remove(id); connections.removeValue(forKey: id)?.cancel() }
    private func accept(_ connection: NWConnection) {
        guard connections.count < 6 else { connection.cancel(); return }
        let id = UUID(); connections[id] = connection; awaitingHeaders.insert(id)
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.close(id) }
            if case .cancelled = state { self?.connections.removeValue(forKey: id) }
        }
        connection.start(queue: queue)
        // Bound incomplete headers, never the installation/transfer duration.
        queue.asyncAfter(deadline: .now() + 20) { [weak self, weak connection] in
            guard let self, connection != nil, self.awaitingHeaders.contains(id) else { return }
            self.close(id)
        }
        receive(connection, id: id, accumulated: Data())
    }
    private func receive(_ connection: NWConnection, id: UUID, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, done, error in
            guard let self, connections[id] != nil else { return }
            let request = accumulated + (data ?? Data())
            guard request.count <= 16384, error == nil else { close(id); return }
            if request.range(of: Data("\r\n\r\n".utf8)) != nil {
                route(connection, id: id, data: request)
            } else if done { close(id) }
            else { receive(connection, id: id, accumulated: request) }
        }
    }
    private func route(_ connection: NWConnection, id: UUID, data: Data) {
        awaitingHeaders.remove(id)
        do {
            let request = try LANHTTP.parse(data)
            guard let base else { close(id); return }
            let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
            if request.path == prefix || request.path == String(prefix.dropLast()) {
                reply(connection, id: id, data: page, type: "text/html; charset=utf-8", head: request.method == "HEAD")
            } else if request.path == prefix + "manifest.plist" {
                reply(connection, id: id, data: manifest, type: "application/xml", head: request.method == "HEAD")
            } else if request.path == prefix + "app.ipa", let ipa {
                let bytes = try LANHTTP.bytes(request.range, size: size)
                let partial = request.range != nil
                let extra = "Accept-Ranges: bytes\r\n" + (partial ? "Content-Range: bytes \(bytes.lowerBound)-\(bytes.upperBound - 1)/\(size)\r\n" : "")
                let header = LANHTTP.header(status: partial ? "206 Partial Content" : "200 OK", type: "application/octet-stream", length: UInt64(bytes.count), extra: extra)
                if request.method == "HEAD" { send(connection, id: id, data: header); return }
                let handle = try FileHandle(forReadingFrom: ipa); try handle.seek(toOffset: bytes.lowerBound)
                connection.send(content: header, completion: .contentProcessed { [weak self] error in
                    guard let self else { try? handle.close(); return }
                    if error != nil { try? handle.close(); close(id); return }
                    stream(connection, id: id, handle: handle, remaining: UInt64(bytes.count), total: UInt64(bytes.count), offset: bytes.lowerBound, fullTransfer: bytes.lowerBound == 0 && bytes.upperBound == size)
                })
            } else { reply(connection, id: id, data: Data(), type: "text/plain", status: "404 Not Found") }
        } catch LANHTTP.Failure.badRange {
            reply(connection, id: id, data: Data(), type: "text/plain", status: "416 Range Not Satisfiable", extra: "Content-Range: bytes */\(size)\r\n")
        } catch { reply(connection, id: id, data: Data(), type: "text/plain", status: "400 Bad Request") }
    }
    private func reply(_ connection: NWConnection, id: UUID, data: Data, type: String, status: String = "200 OK", head: Bool = false, extra: String = "") {
        send(connection, id: id, data: LANHTTP.header(status: status, type: type, length: UInt64(data.count), extra: extra) + (head ? Data() : data))
    }
    private func send(_ connection: NWConnection, id: UUID, data: Data) {
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in self?.close(id) })
    }
    private func stream(_ connection: NWConnection, id: UUID, handle: FileHandle, remaining: UInt64, total: UInt64, offset: UInt64, fullTransfer: Bool) {
        guard connections[id] != nil else { try? handle.close(); return }
        do {
            guard let data = try handle.read(upToCount: Int(min(remaining, 262144))), !data.isEmpty else { throw LANHTTP.Failure.badRequest }
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                guard let self else { try? handle.close(); return }
                guard error == nil else { try? handle.close(); close(id); changed(Status(url: base, error: error?.localizedDescription)); return }
                let left = remaining - UInt64(data.count)
                changed(Status(url: base, progress: Double(offset + total - left) / Double(size), complete: fullTransfer && left == 0))
                if left == 0 { try? handle.close(); close(id) }
                else { stream(connection, id: id, handle: handle, remaining: left, total: total, offset: offset, fullTransfer: fullTransfer) }
            })
        } catch { try? handle.close(); close(id); changed(Status(url: base, error: error.localizedDescription)) }
    }
}
