//
//  String+Localization.swift
//  ZLoader
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit

public extension String {
    init(formatted: String, comment: String? = nil, _ args: String...) {
        self.init(format: NSLocalizedString(formatted, comment: comment ?? ""), args)
    }
}

public func systemLocalizedString(_ string: String) -> String {
    let bundle = Bundle(for: UIApplication.self)
    let localizedString = bundle.localizedString(forKey: string, value: "com.zloader.SystemLocalizedStringNotFound", table: nil)
    if localizedString == "com.zloader.SystemLocalizedStringNotFound" {
        return NSLocalizedString(string, comment: "")
    }
    return localizedString
}
