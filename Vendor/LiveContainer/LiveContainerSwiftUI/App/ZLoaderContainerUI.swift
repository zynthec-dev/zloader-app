import SwiftUI

/// Narrow embedding surface. zLoader owns navigation, Apple login and device
/// installation; the original LiveContainer views own guest app management.
@objc(ZLoaderContainerUI) public final class ZLoaderContainerUI: NSObject {
    private static var prepared = false

    private static func prepare() {
        guard !prepared else { return }
        LiveContainerSwiftUIApp.loadLibrary()
        prepared = true
    }

    @objc public static func appsController() -> UIViewController {
        prepare()
        return UIHostingController(rootView: ZLoaderContainerRoot(settings: false))
    }

    @objc public static func settingsController() -> UIViewController {
        prepare()
        return UIHostingController(rootView: ZLoaderContainerRoot(settings: true))
    }

    @objc public static func openURL(_ url: URL) -> Bool {
        guard ["zloader", "zloader-container"].contains(url.scheme?.lowercased() ?? ""),
              ["livecontainer-launch", "open-url", "container-import", "container-certificate"].contains(url.host?.lowercased() ?? "") else { return false }
        prepare()
        DataManager.shared.model.selectedTab = .apps
        DataManager.shared.model.deepLink = url
        return true
    }

    @objc public static func importIPA(_ url: URL) {
        prepare()
        var components = URLComponents()
        components.scheme = "zloader-container"
        components.host = "container-import"
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        DataManager.shared.model.selectedTab = .apps
        DataManager.shared.model.deepLink = components.url
    }

    @objc public static func configureSigning(_ data: Data, password: String) -> String? {
        do {
            try LCSharedUtils.storeContainerCertificate(data, password: password)
            LCUtils.appGroupUserDefault.set(Date(), forKey: "LCCertificateUpdateDate")
            return nil
        } catch { return error.localizedDescription }
    }
}

private struct ZLoaderContainerRoot: View {
    let settings: Bool
    @StateObject private var downloadHelper = DownloadHelper()
    @StateObject private var sceneDelegate = SceneDelegate()
    @State private var launchError: String?

    var body: some View {
        Group {
            if settings {
                LCSettingsView()
            } else {
                LCAppListView(embeddedInZLoader: true)
            }
        }
        .environmentObject(DataManager.shared.model)
        .environmentObject(LCAppSortManager.shared)
        .environmentObject(downloadHelper)
        .environmentObject(sceneDelegate)
        .downloadAlert(helper: downloadHelper)
        .onAppear {
            sceneDelegate.window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
            if let error = UserDefaults.standard.string(forKey: "error") {
                UserDefaults.standard.removeObject(forKey: "error")
                launchError = error
            }
        }
        .alert("Container konnte nicht gestartet werden", isPresented: Binding(
            get: { launchError != nil }, set: { if !$0 { launchError = nil } })) {
                Button("OK") { launchError = nil }
            } message: { Text(launchError ?? "") }
    }
}

@available(iOS 16.1, *)
@objc(ZLoaderContainerWindowSceneDelegate)
public final class ZLoaderContainerWindowSceneDelegate: NSObject, UIWindowSceneDelegate {
    public var window: UIWindow?
    private let sceneModel = SceneDelegate()

    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene,
              let identifier = (options.userActivities.first ?? session.stateRestorationActivity)?.userInfo?["container"] as? String else { return }
        let window = UIWindow(windowScene: scene)
        sceneModel.window = window
        window.rootViewController = UIHostingController(rootView: MultitaskAppWindow(id: identifier)
            .environmentObject(DataManager.shared.model).environmentObject(sceneModel))
        self.window = window
        session.stateRestorationActivity = options.userActivities.first
        window.makeKeyAndVisible()
    }
}
