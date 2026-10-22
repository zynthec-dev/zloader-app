import Foundation

@main struct ContainerShortcutServerTests {
    static func main() async throws {
        let server = LCShortcutServer()
        let profile = Data("synthetic web-clip configuration".utf8)
        let url = try await server.start(profile: profile)
        precondition(url.host == "127.0.0.1")
        let (page, pageResponse) = try await URLSession.shared.data(from: url)
        precondition((pageResponse as? HTTPURLResponse)?.statusCode == 200)
        precondition(String(decoding: page, as: UTF8.self).contains("Profil laden"))
        let download = url.appendingPathComponent("Container.mobileconfig")
        let (downloaded, response) = try await URLSession.shared.data(from: download)
        precondition(downloaded == profile)
        precondition((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") == "application/x-apple-aspen-config")
        var head = URLRequest(url: download); head.httpMethod = "HEAD"
        let (empty, headResponse) = try await URLSession.shared.data(for: head)
        precondition(empty.isEmpty && (headResponse as? HTTPURLResponse)?.statusCode == 200)
        let (_, denied) = try await URLSession.shared.data(from: url.deletingLastPathComponent().appendingPathComponent("wrong/Container.mobileconfig"))
        precondition((denied as? HTTPURLResponse)?.statusCode == 404)
        var post = URLRequest(url: download); post.httpMethod = "POST"
        let (_, postResponse) = try await URLSession.shared.data(for: post)
        precondition((postResponse as? HTTPURLResponse)?.statusCode == 405)
        await server.stop()
        do { _ = try await URLSession.shared.data(from: url); preconditionFailure("Server must stop with its sheet") }
        catch { }
        print("PASS loopback-only shortcut landing page, exact profile bytes/MIME, HEAD, token isolation, method rejection and shutdown")
    }
}
