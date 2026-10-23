import Foundation

enum Constants {
    enum Anisette { static let remoteRequestTimeout: TimeInterval = 5 }
    enum URLs {
        static let v3GetHeaders = "v3/get_headers"
        static let v3ProvisioningSession = "v3/provisioning_session"
    }
}
enum AnisetteError: Error {
    case badServerResponse(statusCode: Int, payload: String)
    case invalidAnisetteData, invalidURL
    case providerNotReady(String)
}
extension HTTPURLResponse { var isSuccess: Bool { (200..<300).contains(statusCode) } }

final class MockAnisetteProtocol: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var mode = "valid"
    nonisolated(unsafe) static var paths: [String] = []
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "anisette.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let mode = Self.lock.withLock { Self.paths.append(path); return Self.mode }
        let body: String
        var status = 200
        if path == "/v3/client_info" {
            body = #"{"client_info":"Mac identity","user_agent":"akd/provider"}"#
        } else {
            precondition(path == "/v3/get_headers" && request.httpMethod == "POST")
            precondition(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            var data = request.httpBody
            if data == nil, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 4096); var result = Data()
                while stream.hasBytesAvailable {
                    let count = stream.read(&bytes, maxLength: bytes.count)
                    if count <= 0 { break }; result.append(contentsOf: bytes.prefix(count))
                }
                data = result
            }
            let payload = try! JSONSerialization.jsonObject(with: data!) as! [String: String]
            precondition(payload["identifier"] == "AAECAwQFBgcICQoLDA0ODw==")
            precondition(payload["adi_pb"] == Data([1,2,3]).base64EncodedString())
            switch mode {
            case "valid": body = #"{"X-Apple-I-MD":"test-otp","X-Apple-I-MD-M":"test-machine","X-Apple-I-MD-RINFO":"17106176"}"#
            case "missing-routing": body = #"{"X-Apple-I-MD":"test-otp","X-Apple-I-MD-M":"test-machine"}"#
            default: body = "unavailable"; status = 503
            }
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type":"application/json"])!
        client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client!.urlProtocol(self, didLoad: Data(body.utf8))
        client!.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main
struct RemoteAnisetteProtocolTests {
    static func main() async throws {
        precondition(URLProtocol.registerClass(MockAnisetteProtocol.self))
        defer { URLProtocol.unregisterClass(MockAnisetteProtocol.self) }
        let provider = RemoteAnisetteDataProvider(serverURL: URL(string: "https://anisette.invalid")!)
        let identity = try await provider.fetchClientIdentity()
        precondition(identity.clientInfo == "Mac identity" && identity.userAgent == "akd/provider")
        let bytes = Array(UInt8(0)...UInt8(15))
        let result = try await provider.getAnisetteHeaders(libDir: "", provisioningDir: "", identifier: bytes, adiPb: [1,2,3])
        precondition(result.oneTimePassword == "test-otp" && provider.routingInfo == "17106176")
        for mode in ["missing-routing", "unavailable"] {
            MockAnisetteProtocol.lock.withLock { MockAnisetteProtocol.mode = mode }
            do {
                _ = try await provider.getAnisetteHeaders(libDir: "", provisioningDir: "", identifier: bytes, adiPb: [1,2,3])
                preconditionFailure("Bad V3 response accepted")
            } catch {}
        }
        let paths = MockAnisetteProtocol.lock.withLock { MockAnisetteProtocol.paths }
        precondition(paths == ["/v3/client_info", "/v3/get_headers", "/v3/get_headers", "/v3/get_headers"])
        print("PASS real V3 HTTP requests: provider identity, Base64 UUID/blob, routing header; rejected incomplete/503 responses; no shared V1 fallback")
    }
}
