import Foundation

@main struct ArchivePathPolicyTests {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let output = root.appendingPathComponent("output")
        let outside = root.appendingPathComponent("outside")
        try fm.createDirectory(at: output, withIntermediateDirectories: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createSymbolicLink(at: output.appendingPathComponent("escape"), withDestinationURL: outside)
        for path in ["Payload/App.app/Info.plist", "Payload/App.app/Frameworks/F.framework/", "Payload/Äpp.app/Info.plist"] {
            let url = try ArchivePathPolicy.destination(for: path, in: output)
            precondition(url.path.hasPrefix(output.resolvingSymlinksInPath().path + "/"))
        }
        for path in ["", ".", "..", "../outside/stolen", "/absolute/file", "Payload/../../outside/file", "escape/stolen", "x\\..\\outside", "Payload/\0file"] {
            do { _ = try ArchivePathPolicy.destination(for: path, in: output); preconditionFailure("Unsafe archive path accepted: " + path) } catch {}
        }
        let contents = try fm.contentsOfDirectory(atPath: outside.path)
        precondition(contents.isEmpty)
        print("PASS archive extraction confinement: normal app/framework paths preserved; traversal, absolute/NUL/backslash paths and symlink escape rejected")
    }
}
