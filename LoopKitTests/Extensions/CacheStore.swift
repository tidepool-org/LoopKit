//
//  CacheStore.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData
@testable import LoopKit


extension PersistenceController {
    func tearDown() {
        print("****** PersistenceController.tearDown ******")
        managedObjectContext.performAndWait {
            print("****** PersistenceController.tearDown managedObjectContext ******")
            let coordinator = self.managedObjectContext.persistentStoreCoordinator!
            let store = coordinator.persistentStores.first!
            let url = coordinator.url(for: store)
            try! self.managedObjectContext.persistentStoreCoordinator!.remove(store)
            try! self.managedObjectContext.persistentStoreCoordinator!.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
            print("****** PersistenceController.tearDown managedObjectContext end ******")
        }
    }
}
