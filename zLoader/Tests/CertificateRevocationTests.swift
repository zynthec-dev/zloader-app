import Foundation

// Compile the production Certificates.swift against an isolated transport fixture.
// No Apple account, network request, private key or certificate mutation is used.
struct X509Certificate: Sendable {
    enum CertificateEndpoint: String, Sendable {
        case developerPortal, developerServices2
        var url: URL { URL(string: self == .developerPortal ? "https://developer.apple.com/services-account/v1/certificates" : "https://developerservices2.apple.com/services/v1/certificates")! }
    }
    var serialNumber: String
    var identifier: String?
    var sourceEndpoint: CertificateEndpoint?
    var data: Data?
    var name = "fixture"
    var machineName: String?
}
enum TeamType { case free, paid }
struct Team { let type: TeamType; let name = "fixture"; let identifier = "test-team" }
struct Session {}
enum CertificateType {
    case development
    var isPaidOnly: Bool { false }; var displayName: String { "fixture" }; var portalType: String? { "DEVELOPMENT" }
}
struct CertificateRequest {
    let csrData = Data(); let privateKey = Data()
    init(machineName: String) throws {}
}
struct KeyStore { let certificate: X509Certificate; let privateKey: Data }
struct EmptyResponse: Decodable {}
enum ServerError: Error { case underlyingError(code: Int, message: String); case badServerResponse(reason: String, jsonPayload: String) }
enum DeveloperPortalError: Error { case invalidParameters(cause: String); case invalidCertificateRequest(cause: String) }
struct CertificatesResponseDeveloperPortal: Decodable {
    struct Item: Decodable {
        let attributes: Attributes? = nil
        struct Attributes { let certificateType: String? }
        var certificate: X509Certificate? = nil
        func toCertificate() -> X509Certificate? { certificate }
        enum CodingKeys: CodingKey {}
    }
    var data: [Item]?
}
struct CertificatesResponseDeveloperServices2: Decodable {
    var data: [CertificatesResponseDeveloperPortal.Item]?
}
func debugLog(_ value: String) {}
func verboseLog(_ value: String) {}

final class DeveloperPortal {
    struct Event {
        let endpoint: X509Certificate.CertificateEndpoint
        let id: String?
        let certificates: [X509Certificate]
        let error: ServerError?
        init(_ endpoint: X509Certificate.CertificateEndpoint, id: String? = nil, certificates: [X509Certificate] = [], error: ServerError? = nil) {
            self.endpoint = endpoint; self.id = id; self.certificates = certificates; self.error = error
        }
    }
    var events: [Event]
    init(_ events: [Event]) { self.events = events }
    func sendServicesRequest<T: Decodable>(_ request: URLRequest, additionalParameters: [String: String]? = nil,
                                          session: Session, team: Team) async throws -> T {
        precondition(!events.isEmpty, "Unexpected request")
        let event = events.removeFirst()
        let expected = event.id.map { event.endpoint.url.appendingPathComponent($0) } ?? event.endpoint.url
        precondition(request.url == expected, "Wrong host/resource ID")
        precondition(request.httpMethod == (event.id == nil ? "GET" : "DELETE"), "Wrong method")
        if let error = event.error { throw error }
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        let items = event.certificates.map { CertificatesResponseDeveloperPortal.Item(certificate: $0) }
        if T.self == CertificatesResponseDeveloperPortal.self { return CertificatesResponseDeveloperPortal(data: items) as! T }
        return CertificatesResponseDeveloperServices2(data: items) as! T
    }
}

@main struct CertificateRevocationTests {
    static func main() async throws {
        let portal = X509Certificate(serialNumber: "AB12", identifier: "web-id", sourceEndpoint: .developerPortal, data: Data([1, 2, 3]))
        let xcode = X509Certificate(serialNumber: "ab12", identifier: "xcode-id", sourceEndpoint: .developerServices2, data: portal.data)
        let paid = Team(type: .paid); let session = Session()
        let rejected = ServerError.underlyingError(code: 421, message: "fixture")
        let normal = DeveloperPortal([.init(.developerPortal, certificates: [portal]), .init(.developerPortal, id: "web-id"), .init(.developerPortal)])
        let normalResult = try await normal.revokeCertificate(portal, for: paid, session: session); precondition(normalResult); precondition(normal.events.isEmpty)
        let readFallback = DeveloperPortal([.init(.developerPortal, error: rejected), .init(.developerServices2, certificates: [xcode]), .init(.developerServices2, id: "xcode-id"), .init(.developerServices2)])
        let readFallbackResult = try await readFallback.revokeCertificate(portal, for: paid, session: session); precondition(readFallbackResult); precondition(readFallback.events.isEmpty)
        let deleteFallback = DeveloperPortal([.init(.developerPortal, certificates: [portal]), .init(.developerPortal, id: "web-id", error: rejected), .init(.developerServices2, certificates: [xcode]), .init(.developerServices2, id: "xcode-id"), .init(.developerServices2)])
        let deleteFallbackResult = try await deleteFallback.revokeCertificate(portal, for: paid, session: session); precondition(deleteFallbackResult); precondition(deleteFallback.events.isEmpty)
        // Other errors, missing/wrong certificates and repeated 421s must not issue a fallback DELETE.
        for events: [DeveloperPortal.Event] in [
            [.init(.developerPortal, error: .underlyingError(code: 401, message: "fixture"))],
            [.init(.developerPortal, certificates: [portal]), .init(.developerPortal, id: "web-id", error: .underlyingError(code: 403, message: "fixture"))],
            [.init(.developerPortal, certificates: [portal]), .init(.developerPortal, id: "web-id", error: rejected), .init(.developerServices2)],
            [.init(.developerPortal, certificates: [portal]), .init(.developerPortal, id: "web-id", error: rejected), .init(.developerServices2, certificates: [.init(serialNumber: "AB12", identifier: "wrong", sourceEndpoint: .developerServices2, data: Data([9]))])],
            [.init(.developerPortal, error: rejected), .init(.developerServices2, error: rejected)],
            [.init(.developerPortal, certificates: [portal]), .init(.developerPortal, id: "web-id", error: rejected), .init(.developerServices2, certificates: [xcode]), .init(.developerServices2, id: "xcode-id", error: rejected)],
            [.init(.developerPortal, certificates: [portal]), .init(.developerPortal, id: "web-id"), .init(.developerPortal, certificates: [portal])]
        ] {
            let api = DeveloperPortal(events)
            do { _ = try await api.revokeCertificate(portal, for: paid, session: session); preconditionFailure("Must reject unconfirmed revocation") } catch {}
            precondition(api.events.isEmpty)
        }
        let free = DeveloperPortal([.init(.developerServices2, certificates: [xcode]), .init(.developerServices2, id: "xcode-id"), .init(.developerServices2)])
        let freeResult = try await free.revokeCertificate(xcode, for: Team(type: .free), session: session); precondition(freeResult); precondition(free.events.isEmpty)
        print("PASS certificate revocation: normal/free paths, read/DELETE 421 routing, endpoint-local IDs, DER identity, no 401/403 retry, bounded fallback, remote confirmation")
    }
}
