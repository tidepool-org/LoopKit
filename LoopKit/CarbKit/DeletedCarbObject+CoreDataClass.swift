//
//  DeletedCarbObject+CoreDataClass.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData

// DEPRECATED: Remains only to facilitate migration to updated CachedCarbObject

class DeletedCarbObject: NSManagedObject {
    var uploadState: UploadState {
        get {
            willAccessValue(forKey: "uploadState")
            defer { didAccessValue(forKey: "uploadState") }
            return UploadState(rawValue: primitiveUploadState!.intValue)!
        }
        set {
            willChangeValue(forKey: "uploadState")
            defer { didChangeValue(forKey: "uploadState") }
            primitiveUploadState = NSNumber(value: newValue.rawValue)
        }
    }

    override func willSave() {
        if isInserted || isUpdated {
            setPrimitiveValue(managedObjectContext!.modificationCounter ?? 0, forKey: "modificationCounter")
        }
        super.willSave()
    }
}

extension CachedCarbObject {
    func update(from deletedObject: DeletedCarbObject) {
        recordDate = nil
        primitiveAbsorptionTime = nil
        createdByCurrentApp = true
        externalID = deletedObject.externalID
        foodType = nil
        grams = 0
        startDate = deletedObject.startDate
        uploadState = deletedObject.uploadState
        uuid = deletedObject.uuid
        syncIdentifier = deletedObject.syncIdentifier
        syncVersion = deletedObject.syncVersion
        isActive = false
    }
}
