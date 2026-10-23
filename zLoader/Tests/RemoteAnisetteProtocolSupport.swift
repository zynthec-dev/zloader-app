import Foundation

// Minimal AnisetteKit protocol types for compiling the production HTTP provider
// in isolation. The HTTP implementation under test is the real SideSign file.
public struct AnisetteDataResponse: Sendable {
    public let oneTimePassword: String
    public let machineID: String
    public init(from dictionary: [String: String]) throws {
        guard let otp = dictionary["X-Apple-I-MD"], let machine = dictionary["X-Apple-I-MD-M"] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        oneTimePassword = otp; machineID = machine
    }
}
public protocol AnisetteDataProvider: Sendable {
    var requiresLocalLibraries: Bool { get }
    func getAnisetteHeaders(libDir: String, provisioningDir: String, identifier: [UInt8], adiPb: [UInt8]) async throws -> AnisetteDataResponse
    func startProvision(libDir: String, provisioningDir: String, identifier: [UInt8], spim: [UInt8]) async throws -> (cpim: Data, session: UInt32)
    func endProvision(libDir: String, provisioningDir: String, identifier: [UInt8], session: UInt32, ptm: [UInt8], tk: [UInt8]) async throws -> Data
}
