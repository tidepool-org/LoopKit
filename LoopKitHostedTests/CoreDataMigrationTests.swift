//
//  CoreDataMigrationTests.swift
//  LoopKitHostedTests
//
//  Created by Rick Pasetto on 8/9/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import CoreData
import HealthKit
import XCTest
@testable import LoopKit

class CoreDataMigrationTests: XCTestCase {
    
    var cacheStore: PersistenceController!
    let fileManager = FileManager()
    static let v1ModelURL = Bundle(for: CoreDataMigrationTests.self).bundleURL

    override func setUpWithError() throws {
        try fileManager.copyItem(at: CoreDataMigrationTests.v1ModelURL.appendingPathComponent("Model.sqlite.original"),
                                 to: CoreDataMigrationTests.v1ModelURL.appendingPathComponent("Model.sqlite"))
    }

    override func tearDownWithError() throws {
        
        // remove all stores
        try cacheStore.managedObjectContext.persistentStoreCoordinator?.persistentStores.forEach { store in
            try cacheStore.managedObjectContext.persistentStoreCoordinator?.remove(store)
        }
        
        try fileManager.removeItem(at: CoreDataMigrationTests.v1ModelURL.appendingPathComponent("Model.sqlite"))
        cacheStore = nil
    }

    func testMigration() throws {
        let e = expectation(description: #function)
        cacheStore = PersistenceController.init(directoryURL: CoreDataMigrationTests.v1ModelURL)
        var error: Error?
        cacheStore.onReady {
            if let err = $0 {
                error = err
                XCTFail("Error opening \(CoreDataMigrationTests.v1ModelURL): \(err)")
            }
            e.fulfill()
        }
        wait(for: [e], timeout: 10.0)
        if let error = error { throw error }
//        print("\(String(describing: cacheStore.managedObjectContext.persistentStoreCoordinator?.managedObjectModel.entities))")
        
        var entries: [CachedCarbObject]!
        let e0 = expectation(description: #function)
        cacheStore.managedObjectContext.performAndWait {
            do {
                entries = try cacheStore.managedObjectContext.fetch(CachedCarbObject.fetchRequest())
            } catch let err {
                error = err
            }
            e0.fulfill()
        }
        wait(for: [e0], timeout: 1.0)
        if let error = error { throw error }
        print("entries.count = \(entries.count)")
        print("entries = \(entries.map { $0.quantity })")
        XCTAssertEqual(1, entries.count)
    }
}
