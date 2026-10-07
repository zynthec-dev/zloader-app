import Foundation

enum LANHTTP {
    struct Request {
        let method: String
        let path: String
        let range: String?
    }
    enum Failure: Error { case badRequest, badRange }
    static func parse(_ data: Data) throws -> Request {
        guard data.count <= 16384, let text = String(data: data, encoding: .utf8), text.hasSuffix("\r\n\r\n") else { throw Failure.badRequest }
        let lines = text.components(separatedBy: "\r\n")
        let parts = lines[0].split(separator: " ")
        guard parts.count == 3, ["GET", "HEAD"].contains(String(parts[0])), parts[2] == "HTTP/1.1" || parts[2] == "HTTP/1.0",
              parts[1].hasPrefix("/"), !parts[1].contains(".."), !parts[1].contains("%") else { throw Failure.badRequest }
        var range: String?
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { throw Failure.badRequest }
            let name = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if name == "range" { guard range == nil else { throw Failure.badRequest }; range = value }
            if name == "transfer-encoding" || (name == "content-length" && value != "0") { throw Failure.badRequest }
        }
        return Request(method: String(parts[0]), path: String(parts[1]), range: range)
    }
    static func bytes(_ range: String?, size: UInt64) throws -> Range<UInt64> {
        guard size > 0 else { throw Failure.badRange }
        guard let range else { return 0..<size }
        guard range.hasPrefix("bytes="), !range.contains(",") else { throw Failure.badRange }
        let parts = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw Failure.badRange }
        if parts[0].isEmpty {
            guard let suffix = UInt64(parts[1]), suffix > 0 else { throw Failure.badRange }
            return (size - min(size, suffix))..<size
        }
        guard let start = UInt64(parts[0]), start < size else { throw Failure.badRange }
        let end: UInt64
        if parts[1].isEmpty { end = size - 1 }
        else { guard let requested = UInt64(parts[1]), requested >= start else { throw Failure.badRange }; end = min(requested, size - 1) }
        return start..<(end + 1)
    }
    static func header(status: String, type: String, length: UInt64, extra: String = "") -> Data {
        Data("HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(length)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\(extra)\r\n".utf8)
    }
    static func manifest(base: URL, bundleID: String, version: String, name: String) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: ["items": [[
            "assets": [["kind": "software-package", "url": base.appendingPathComponent("app.ipa").absoluteString]],
            "metadata": ["bundle-identifier": bundleID, "bundle-version": version, "kind": "software", "title": name]
        ]]], format: .xml, options: 0)
    }
    static func page(base: URL, name: String) -> Data {
        let safeName = name.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: "\"", with: "&quot;")
        var url = URLComponents(); url.scheme = "itms-services"; url.host = ""; url.queryItems = [URLQueryItem(name: "action", value: "download-manifest"), URLQueryItem(name: "url", value: base.appendingPathComponent("manifest.plist").absoluteString)]
        let link = (url.string ?? "").replacingOccurrences(of: "&", with: "&amp;")
        return Data("""
        <!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>zLoader IPA Installer</title>
        <style>body{font:17px system-ui;max-width:36em;margin:3em auto;padding:1em;color:CanvasText;background:Canvas;color-scheme:light dark}a{display:block;margin:1em 0;padding:1em;border-radius:1em;background:#147d60;color:white;text-decoration:none}</style>
        <h1>\(safeName)</h1><p>The IPA must be signed for this device. HTTPS trust does not grant app signing permissions. Keep zLoader open on the sender.</p>
        <a href="\(link)">Install App</a><a href="app.ipa">Download IPA</a><p>Install the shared zLoader certificate profile and enable its full trust in Settings → General → About → Certificate Trust Settings before installation.</p></html>
        """.utf8)
    }
}
