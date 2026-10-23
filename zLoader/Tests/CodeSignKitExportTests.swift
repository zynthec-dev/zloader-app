import Foundation
import CodeSignKit

@main struct CodeSignKitExportTests {
    static func main() throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let certificate = try Data(contentsOf: folder.appendingPathComponent("certificate.der"))
        let key = try Data(contentsOf: folder.appendingPathComponent("private.pem"))
        for password in ["test-password", "Grün🔑123"] {
            let exported = try PortablePKCS12.build(certificate: certificate, key: key, password: password, name: "zLoader Test")
            let parsed = try PKCS12Parser(p12Data: exported, password: password)
            guard let decodedKey = parsed.privateKeyDER else { fatalError("Missing key after import") }
            precondition(parsed.leafCertificate != nil && parsed.rsaPrivateKey != nil)
            precondition(PortablePKCS12.rsaKeyDER(decodedKey) == PortablePKCS12.rsaKeyDER(key))
            do {
                _ = try PKCS12Parser(p12Data: exported, password: "incorrect")
                fatalError("Wrong password accepted by signing parser")
            } catch {}
        }
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>com.apple.developer.carplay-audio</key><true/><key>get-task-allow</key><true/><key>test-array</key><array><string>one</string><string>two</string></array></dict></plist>
        """
        // Exact bytes generated independently by Apple's codesign for this plist.
        let expected = "705c020101b05730260c21636f6d2e6170706c652e646576656c6f7065722e636172706c61792d617564696f0101ff30130c0e6765742d7461736b2d616c6c6f770101ff30180c0a746573742d6172726179300a0c036f6e650c0374776f"
        let actual = DEREncoder.encodePlistXML(xml)!
        precondition(actual.map { String(format: "%02x", $0) }.joined() == expected)
        let executable = folder.appendingPathComponent("fixture")
        let signed = try MachOSigner(binaryData: Data(contentsOf: executable), bundleIdentifier: "test.der",
            teamIdentifier: nil, entitlementsXML: xml, infoPlistData: nil,
            codeResourcesData: nil, cmsSigner: nil, options: [.adHoc]).sign()
        try signed.write(to: executable)
        let host = folder.appendingPathComponent("ExtensionKit.app")
        let helper = host.appendingPathComponent("Extensions/iOSHelper.appex")
        let original = "com.utmapp.UTM"
        let resolved = original + ".QA12345678"
        for (url, id) in [(host, original), (helper, original + ".iOSHelper")] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleExecutable": "TestExecutable",
                "CFBundlePackageType": url == host ? "APPL" : "XPC!", "CFBundleVersion": "1"]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
            try data.write(to: url.appendingPathComponent("Info.plist"))
            try signed.write(to: url.appendingPathComponent("TestExecutable"))
        }
        let components = try BundleSigningLayout.componentURLs(in: host)
        precondition(components.count == 2)
        let identities = [original: resolved, original + ".iOSHelper": resolved + ".iOSHelper"]
        var entitlementsByPath: [String: String] = [:]
        for url in components {
            let plistURL = url.appendingPathComponent("Info.plist")
            let data = try Data(contentsOf: plistURL)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
            let updated = try BundleSigningLayout.rewriting(plist, identities: identities)
            try PropertyListSerialization.data(fromPropertyList: updated, format: .binary, options: 0).write(to: plistURL)
            let id = updated["CFBundleIdentifier"] as! String
            let entitlements: [String: Any] = ["application-identifier": "QA12345678." + id,
                "com.apple.developer.team-identifier": "QA12345678", "test-owner": url == host ? "host" : "helper"]
            let encoded = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0)
            let path = url == host ? "" : String(url.path.dropFirst(host.path.count + 1))
            entitlementsByPath[path] = String(data: encoded, encoding: .utf8)!
        }
        try BundleSigningLayout.validateIdentifiers(in: host)
        try CodeSigner.signAdHoc(appPath: host.path, entitlementProvider: { entitlementsByPath[$0] ?? "" })
        for url in components {
            let xml = try MachOParser.entitlements(at: url)
            let signedEntitlements = try PropertyListSerialization.propertyList(from: Data(xml.utf8), format: nil) as! [String: Any]
            let id = url == host ? resolved : resolved + ".iOSHelper"
            precondition(signedEntitlements["application-identifier"] as? String == "QA12345678." + id)
            precondition(signedEntitlements["test-owner"] as? String == (url == host ? "host" : "helper"))
        }
        print("PASS actual CodeSignKit signs host and ExtensionKit helper with distinct final IDs and entitlement ownership")
        print("PASS canonical DER matches Apple reference and MachOSigner produces regression fixture")
        print("PASS pinned CodeSignKit imports ASCII/Unicode encrypted exports, preserves private key and rejects wrong password")
    }
}
