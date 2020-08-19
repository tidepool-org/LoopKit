//
//  DeletedCarbObject+CoreDataClass.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData

// MARK: - DEPRECATED - Used only for migration

class DeletedCarbObject: NSManagedObject {
    class DeprecatedError: Error {}

    override func validateForInsert() throws {
        throw DeprecatedError()
    }

    override func validateForUpdate() throws {
        throw DeprecatedError()
    }
}
