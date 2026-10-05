//
//  ALTApplication+ZLoaderApp.swift
//  ZLoader
//
//  Created by Riley Testut on 11/11/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import SideSign

extension ALTApplication {
    var isZLoaderApp: Bool {
        if self.fileURL.standardizedFileURL == Bundle.Info.activeBundleURL.standardizedFileURL {
            return true
        }
        return self.bundleIdentifier.isZLoaderAppID
    }
}
