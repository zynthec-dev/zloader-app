//
//  OperationEntitlements.swift
//  ZLoader
//
//  Created by Magesh K on 30/07/26.
//  Copyright © 2026 AltStore. All rights reserved.
//

import Foundation
import SideSign

struct OperationEntitlements {
    // Sign the rights declared by the IPA. Extra rights are an explicit customization,
    // not unconditional memory capabilities inserted into every app and profile.
    static let defaultAdditionalEntitlements: [ALTEntitlement: any Sendable] = [:]
}
