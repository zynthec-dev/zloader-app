import Foundation

@main
struct AppleLoginCompatibilityTests {
    static func main() async throws {
        let original = "<Mac> <macOS> <AuthKit>"
        for path in ["/grandslam/GsService2", "/grandslam/GsService2/validate"] {
            let value = AppleLoginCompatibility.clientInfo(for: URL(string: "https://gsa.apple.com" + path)!, anisetteClientInfo: original)
            precondition(value == original)
        }
        for address in [
            "https://gsa.apple.com/auth/verify/trusteddevice",
            "https://gsa.apple.com/auth/verify/phone/put?mode=sms",
            "https://idmsa.apple.com/appleauth/auth/devices",
            "https://gsa.apple.com.example/grandslam/GsService2",
            "http://gsa.apple.com/grandslam/GsService2",
            "https://gsa.apple.com/auth/verify?next=/grandslam/GsService2"
        ] {
            precondition(AppleLoginCompatibility.clientInfo(for: URL(string: address)!, anisetteClientInfo: original) == original)
        }
        precondition(AppleLoginCompatibility.authenticationType(response: [:], status: ["hsc": 409]) == "pushedCode")
        precondition(AppleLoginCompatibility.authenticationType(response: [:], status: ["hsc": 200]) == nil)
        precondition(AppleLoginCompatibility.authenticationType(response: [:], status: nil) == nil)
        for kind in ["trustedDeviceSecondaryAuth", "sms", "voice", "repair"] {
            precondition(AppleLoginCompatibility.authenticationType(response: [:], status: ["au": kind, "hsc": 409]) == kind)
            precondition(AppleLoginCompatibility.authenticationType(response: ["au": kind], status: ["hsc": 409]) == kind)
        }
        precondition(AppleLoginCompatibility.authenticationType(response: ["au": "sms"], status: ["au": "repair"]) == "repair")
        precondition(!AppleLoginCompatibility.pushedCodeHandled)
        await AppleLoginCompatibility.$pushedCodeHandled.withValue(true) {
            precondition(AppleLoginCompatibility.pushedCodeHandled)
            let inherited = await Task { AppleLoginCompatibility.pushedCodeHandled }.value
            precondition(inherited)
            await Task.yield()
            precondition(AppleLoginCompatibility.pushedCodeHandled)
        }
        precondition(!AppleLoginCompatibility.pushedCodeHandled)
        let independentLogin = await Task { AppleLoginCompatibility.pushedCodeHandled }.value
        precondition(!independentLogin)
        let gsa = URL(string: "https://gsa.apple.com/grandslam/GsService2")!
        let verify = URL(string: "https://gsa.apple.com/auth/verify/trusteddevice")!
        let failure = AppleLoginCompatibility.HTTPFailure(statusCode: 503, phase: .initialization, retryAfter: nil)
        let result: String = try await AppleLoginCompatibility.retryHandshake503(after: failure, pause: { delay in
            precondition(delay == 5)
            precondition(!AppleLoginCompatibility.hasRetriedHandshake)
        }, attempt: {
            precondition(AppleLoginCompatibility.hasRetriedHandshake)
            let identity = AppleLoginCompatibility.clientInfo(for: gsa, anisetteClientInfo: original)
            precondition(identity == original)
            precondition(AppleLoginCompatibility.clientInfo(for: verify, anisetteClientInfo: original) == original)
            precondition(AppleLoginCompatibility.clientInfo(for: URL(string: "https://gsa.apple.com/grandslam/GsService2/validate")!, anisetteClientInfo: original) == identity)
            let inherited = await Task { AppleLoginCompatibility.hasRetriedHandshake }.value
            precondition(inherited)
            return "retried once"
        })
        precondition(result == "retried once" && !AppleLoginCompatibility.hasRetriedHandshake)
        let proofFailure = AppleLoginCompatibility.HTTPFailure(statusCode: 503, phase: .proof, retryAfter: nil)
        let proofResult: String = try await AppleLoginCompatibility.retryHandshake503(after: proofFailure,
            pause: { precondition($0 == 5) }, attempt: {
                precondition(AppleLoginCompatibility.hasRetriedHandshake)
                return "fresh handshake"
            })
        precondition(proofResult == "fresh handshake" && !AppleLoginCompatibility.hasRetriedHandshake)
        for denied in [
            AppleLoginCompatibility.HTTPFailure(statusCode: 503, phase: .appTokens, retryAfter: nil),
            .init(statusCode: 503, phase: .other, retryAfter: nil),
            .init(statusCode: 429, phase: .initialization, retryAfter: nil),
            .init(statusCode: 500, phase: .initialization, retryAfter: nil),
            .init(statusCode: 503, phase: .initialization, retryAfter: 120),
            .init(statusCode: 503, phase: .initialization, retryAfter: .infinity)
        ] {
            do {
                let _: Int = try await AppleLoginCompatibility.retryHandshake503(after: denied,
                    pause: { _ in preconditionFailure("Must not sleep") },
                    attempt: { preconditionFailure("Must not retry") })
                preconditionFailure("Expected HTTP failure")
            } catch let error as AppleLoginCompatibility.HTTPFailure {
                precondition(error.statusCode == denied.statusCode && error.phase == denied.phase)
            }
        }
        do {
            let _: Int = try await AppleLoginCompatibility.retryHandshake503(after: failure,
                pause: { _ in throw CancellationError() },
                attempt: { preconditionFailure("Cancelled retry must not run") })
            preconditionFailure("Expected cancellation")
        } catch is CancellationError {}
        do {
            let _: Int = try await AppleLoginCompatibility.retryHandshake503(after: failure, pause: { _ in }, attempt: {
                do {
                    let _: Int = try await AppleLoginCompatibility.retryHandshake503(after: proofFailure,
                        pause: { _ in preconditionFailure("No second delay") },
                        attempt: { preconditionFailure("No second fallback") })
                    preconditionFailure("Expected terminal HTTP failure")
                } catch let error as AppleLoginCompatibility.HTTPFailure { throw error }
            })
            preconditionFailure("Expected fallback failure")
        } catch let error as AppleLoginCompatibility.HTTPFailure { precondition(error.statusCode == 503) }
        try await AppleLoginCompatibility.$pushedCodeHandled.withValue(true) {
            do {
                let _: Int = try await AppleLoginCompatibility.retryHandshake503(after: failure,
                    pause: { _ in preconditionFailure("Do not repeat after 2FA") },
                    attempt: { preconditionFailure("Do not repeat after 2FA") })
                preconditionFailure("Expected terminal error")
            } catch is AppleLoginCompatibility.HTTPFailure {}
        }
        let bytes = Array(UInt8(0)...UInt8(15))
        precondition(AppleLoginCompatibility.encodedIdentifier(bytes) == "AAECAwQFBgcICQoLDA0ODw==")
        let identity = try AppleLoginCompatibility.RemoteIdentity.decode(Data(
            #"{"client_info":"<MacBookPro13,3> <Mac OS X;10.12.6;16G29> <AuthKit>","user_agent":"akd/1.0"}"#.utf8))
        precondition(identity.clientInfo.contains("MacBookPro13,3") && identity.userAgent == "akd/1.0")
        for payload in [#"{}"#, #"{"client_info":"", "user_agent":"akd"}"#,
                        #"{"client_info":"Mac", "user_agent":"akd\r\nInjected: x"}"#] {
            do {
                _ = try AppleLoginCompatibility.RemoteIdentity.decode(Data(payload.utf8))
                preconditionFailure("Invalid remote identity accepted")
            } catch {}
        }
        precondition(!AppleLoginCompatibility.hasRetriedHandshake)
        let _: Bool = try await AppleLoginCompatibility.retryHandshake503(after:
            AppleLoginCompatibility.HTTPFailure(statusCode: 503, phase: .initialization, retryAfter: 12),
            pause: { precondition($0 == 12) }, attempt: { true })
        precondition(failure.errorDescription?.contains("503") == true)
        precondition(failure.errorDescription?.contains("starting sign-in") == true)
        print("PASS provider identity retained across provisioning/SRP/2FA; pushed-code inference and explicit auth precedence; per-login retry state inheritance/reset; one cancellable init/proof 503 fresh-handshake retry; no token/code/rate-limit retry; Retry-After bounds")
    }
}
