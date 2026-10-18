import Foundation

@main
struct AppleLoginCompatibilityTests {
    static func main() async {
        let original = "<Mac> <macOS> <AuthKit>"
        for path in ["/grandslam/GsService2", "/grandslam/GsService2/validate"] {
            let value = AppleLoginCompatibility.clientInfo(for: URL(string: "https://gsa.apple.com" + path)!, anisetteClientInfo: original)
            precondition(value.contains("<Android;"))
            precondition(value != original)
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
        print("PASS GrandSlam-only Android identity; original 2FA/SMS identity; pushed-code inference and explicit auth precedence; per-login retry state inheritance and reset")
    }
}
