import Foundation
import Network

/// Serves only the generated web-clip profile on loopback while its sheet is open.
/// No IPA, signing identity, other file or externally bound listener is exposed.
actor LCShortcutServer {
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private let queue = DispatchQueue(label: "de.zloader.container-shortcut")

    func start(profile: Data) async throws -> URL {
        stop()
        let token = UUID().uuidString
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.newConnectionHandler = { [weak self, weak listener] connection in
            Task { await self?.accept(connection, listener: listener, token: token, profile: profile) }
        }
        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            let ready = Ready(continuation)
            listener.stateUpdateHandler = { [weak listener] state in
                switch state {
                case .ready:
                    if let port = listener?.port { Task { await ready.finish(.success(port.rawValue)) } }
                case .failed(let error): Task { await ready.finish(.failure(error)) }
                case .cancelled: Task { await ready.finish(.failure(CancellationError())) }
                default: break
                }
            }
            listener.start(queue: queue)
        }
        return URL(string: "http://127.0.0.1:\(port)/\(token)/")!
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
    }

    private func accept(_ connection: NWConnection, listener: NWListener?, token: String, profile: Data) {
        guard let listener, self.listener === listener else { connection.cancel(); return }
        let identifier = UUID()
        connections[identifier] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed: Task { await self?.remove(identifier) }
            default: break
            }
        }
        connection.start(queue: queue)
        Self.receive(connection, buffer: Data(), token: token, profile: profile)
        queue.asyncAfter(deadline: .now() + 5) { connection.cancel() }
    }

    private func remove(_ identifier: UUID) { connections.removeValue(forKey: identifier) }

    private static func receive(_ connection: NWConnection, buffer: Data, token: String, profile: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, ended, error in
            var header = buffer
            if let data { header.append(data) }
            guard header.count <= 16_384 else { connection.cancel(); return }
            if header.range(of: Data("\r\n\r\n".utf8)) != nil {
                respond(connection, header: header, token: token, profile: profile)
            } else if !ended && error == nil {
                receive(connection, buffer: header, token: token, profile: profile)
            } else { connection.cancel() }
        }
    }

    private static func respond(_ connection: NWConnection, header: Data, token: String, profile: Data) {
        let request = String(decoding: header, as: UTF8.self).components(separatedBy: "\r\n")[0].split(separator: " ")
        let method = request.first.map(String.init) ?? ""
        let path = request.count == 3 ? String(request[1]) : ""
        let landing = "/\(token)/"
        let download = landing + "Container.mobileconfig"
        let status: String
        let type: String
        let body: Data
        if method != "GET" && method != "HEAD" {
            status = "405 Method Not Allowed"; type = "text/plain"; body = Data()
        } else if path == download {
            status = "200 OK"; type = "application/x-apple-aspen-config"; body = profile
        } else if path == landing {
            status = "200 OK"; type = "text/html; charset=utf-8"
            body = Data("""
                <!doctype html><html lang="de"><meta name="viewport" content="width=device-width,initial-scale=1">
                <title>Container-Verknüpfung</title><body style="font:17px system-ui;padding:24px;line-height:1.5">
                <h1>Zum Home-Bildschirm</h1><p><a href="\(download)">Profil laden</a></p>
                <p>Bestätige den Download und öffne danach „Profil geladen“ in den iOS-Einstellungen.
                Mit „Installieren“ fügt iOS die Verknüpfung hinzu. Die App läuft weiterhin in zLoader.</p>
                <p>Schließe dieses Fenster erst nach dem Download.</p></body></html>
                """.utf8)
        } else {
            status = "404 Not Found"; type = "text/plain"; body = Data()
        }
        var response = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n"
        if path == download && status == "200 OK" { response += "Content-Disposition: attachment; filename=\"Container.mobileconfig\"\r\n" }
        response += "\r\n"
        var bytes = Data(response.utf8)
        if method != "HEAD" { bytes.append(body) }
        connection.send(content: bytes, completion: .contentProcessed { _ in connection.cancel() })
    }

    private actor Ready {
        private var continuation: CheckedContinuation<UInt16, Error>?
        init(_ continuation: CheckedContinuation<UInt16, Error>) { self.continuation = continuation }
        func finish(_ result: Result<UInt16, Error>) {
            continuation?.resume(with: result)
            continuation = nil
        }
    }
}
