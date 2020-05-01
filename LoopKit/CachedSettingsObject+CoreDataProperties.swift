//
//  CachedSettingsObject+CoreDataProperties.swift
//  LoopKit
//
//  Created by Darin Krauss on 4/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData

extension CachedSettingsObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedSettingsObject> {
        return NSFetchRequest<CachedSettingsObject>(entityName: "CachedSettingsObject")
    }

    @NSManaged public var data: Data
    @NSManaged public var date: Date
    @NSManaged public var modificationCounter: Int64
}
