//
//  StoreAppPolicy.swift
//  ZLoader
//
//  Created by Riley Testut on 9/14/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData

@objc(StoreAppToStoreAppMigrationPolicy)
class StoreAppToStoreAppMigrationPolicy: NSEntityMigrationPolicy
{
    @objc(migrateIconURL)
    func migrateIconURL() -> URL
    {
        return URL(string: "https://via.placeholder.com/150")!
    }
    
    @objc(migrateScreenshotURLs)
    func migrateScreenshotURLs() -> NSCopying
    {
        return [] as NSArray
    }
}
