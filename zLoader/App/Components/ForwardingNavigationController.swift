//
//  ForwardingNavigationController.swift
//  ZLoader
//
//  Created by Riley Testut on 10/24/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

final class ForwardingNavigationController: UINavigationController
{
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        viewController.loadViewIfNeeded()
        ThemeManager.shared.applyAppearance(to: viewController.view)
        super.pushViewController(viewController, animated: animated)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.shared.applyAppearance(to: view)
    }

#if !os(tvOS)
    override var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
    
    override var childForStatusBarHidden: UIViewController? {
        return self.topViewController
    }
#endif
}
