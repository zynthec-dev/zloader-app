//
//  LCAppBanner.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/21.
//

import Foundation
import SwiftUI
import UIKit

protocol LCAppBannerDelegate {
    func removeApp(app: LCAppModel)
    func installMdm(data: Data)
    func openNavigationView(view: AnyView)
    func promptForGeneratedIconStyle() async -> GeneratedIconStyle?
}

struct LCAppBanner: UIViewControllerRepresentable {
    var delegate: LCAppBannerDelegate
    let launcherStyle: Bool

    @ObservedObject var model: LCAppModel

    @AppStorage("dynamicColors", store: LCUtils.appGroupUserDefault) private var dynamicColors = true
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    private let sharedModel = DataManager.shared.model

    init(appModel: LCAppModel, delegate: LCAppBannerDelegate, launcherStyle: Bool = false) {
        self.launcherStyle = launcherStyle
        _model = ObservedObject(wrappedValue: appModel)
        self.delegate = delegate
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = LCAppBannerViewController(delegate: delegate, config: LCAppBannerConfiguration(model: model, dynamicColors: dynamicColors, darkModeIcon: darkModeIcon, launcherStyle: launcherStyle))
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let viewController = uiViewController as? LCAppBannerViewController else {
            return
        }
        viewController.update(
            model: model,
            dynamicColors: dynamicColors,
            darkModeIcon: darkModeIcon
        )
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIViewController, context: Context) -> CGSize? {
        guard let width = proposal.width else {
            return nil
        }
        if launcherStyle {
            let font = UIFont.preferredFont(forTextStyle: .footnote)
            let nameHeight = (model.displayName as NSString).boundingRect(
                with: CGSize(width: max(1, width - 4), height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height
            return CGSize(width: width, height: min(112, width - 4) + 4 + ceil(max(font.lineHeight * 2, nameHeight)) + 2 + ceil(UIFont.preferredFont(forTextStyle: .caption2).lineHeight) + 16)
        }
        return CGSize(width: width, height: LCAppBannerRootView.bannerHeight)
    }
}
