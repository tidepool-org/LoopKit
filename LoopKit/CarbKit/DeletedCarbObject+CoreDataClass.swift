//
//  DeletedCarbObject+CoreDataClass.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData


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
        if !isDeleted {
            setPrimitiveValue(Date(), forKey: "modifiedDate")
        }
        super.willSave()
    }
}


extension DeletedCarbObject {

    func update(from entry: CachedCarbObject) {
        externalID = entry.externalID
        uploadState = entry.uploadState
        uuid = entry.uuid
        syncIdentifier = entry.syncIdentifier
        syncVersion = entry.syncVersion
    }

}
