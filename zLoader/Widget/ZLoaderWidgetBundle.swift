//
//  ZLoaderWidgetBundle.swift
//  ZLoaderWidget
//
//  Created by Riley Testut on 8/22/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import WidgetKit

@main
struct ZLoaderWidgetBundle: WidgetBundle
{
    var body: some Widget {
        AppDetailWidget()
        
        IconLockScreenWidget()
        TextLockScreenWidget()
        
        ActiveAppsWidget()
    }
}
