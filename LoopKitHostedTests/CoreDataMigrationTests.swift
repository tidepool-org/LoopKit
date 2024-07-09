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
    
    private let momdURL = Bundle(for: CoreDataMigrationTests.self).url(forResource: "App", withExtension: "momd")!
    private let storeType = NSSQLiteStoreType

    
    /// Create and load a store using the given model version. The store will be located in a
    /// temporary directory.
    ///
    /// - Parameter versionName: The name of the model (`.xcdatamodel`). For example, `"App V1"`.
    /// - Returns: An `NSPersistentContainer` that is loaded and ready for usage.
    func startPersistentContainer(_ versionName: String) throws -> NSPersistentContainer {
        let storeURL = makeTemporaryStoreURL()
        let model = managedObjectModel(versionName: versionName)

        let container = makePersistentContainer(storeURL: storeURL,
                                                managedObjectModel: model)
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }

        return container
    }

    /// Migrates the given `container` to a new store URL. The new (migrated) store will be located
    /// in a temporary directory.
    ///
    /// - Parameter container: The `NSPersistentContainer` containing the source store that will be
    ///                        migrated.
    /// - Parameter versionName: The name of the model (`.xcdatamodel`) to migrate to. For example,
    ///                          `"App V2"`.
    ///
    /// - Returns: A migrated `NSPersistentContainer` that is loaded and ready for usage. This
    ///            container uses a different store URL than the original `container`.
    func migrate(container: NSPersistentContainer, to versionName: String) throws -> NSPersistentContainer {
        // Define the source and destination `NSManagedObjectModels`.
        let sourceModel = container.managedObjectModel
        let destinationModel = managedObjectModel(versionName: versionName)

        let sourceStoreURL = storeURL(from: container)
        // Create a new temporary store URL. This is where the migrated data using the model
        // will be located.
        let destinationStoreURL = makeTemporaryStoreURL()

        // Infer a mapping model between the source and destination `NSManagedObjectModels`.
        // Modify this line if you use a custom mapping model.
        let mappingModel = try NSMappingModel.inferredMappingModel(forSourceModel: sourceModel,
                                                                   destinationModel: destinationModel)

        let migrationManager = NSMigrationManager(sourceModel: sourceModel,
                                                  destinationModel: destinationModel)
        // Migrate the `sourceStoreURL` to `destinationStoreURL`.
        try migrationManager.migrateStore(from: sourceStoreURL,
                                          sourceType: storeType,
                                          options: nil,
                                          with: mappingModel,
                                          toDestinationURL: destinationStoreURL,
                                          destinationType: storeType,
                                          destinationOptions: nil)

        // Load the store at `destinationStoreURL` and return the migrated container.
        let destinationContainer = makePersistentContainer(storeURL: destinationStoreURL,
                                                           managedObjectModel: destinationModel)
        destinationContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }

        return destinationContainer
    }

    private func makePersistentContainer(storeURL: URL,
                                         managedObjectModel: NSManagedObjectModel) -> NSPersistentContainer {
        let description = NSPersistentStoreDescription(url: storeURL)
        // In order to have more control over when the migration happens, we're setting
        // `shouldMigrateStoreAutomatically` to `false` to stop `NSPersistentContainer`
        // from **automatically** migrating the store. Leaving this as `true` might result in false positives.
        description.shouldMigrateStoreAutomatically = false
        description.type = storeType

        let container = NSPersistentContainer(name: "App Container", managedObjectModel: managedObjectModel)
        container.persistentStoreDescriptions = [description]

        return container
    }

    private func managedObjectModel(versionName: String) -> NSManagedObjectModel {
        let url = momdURL.appendingPathComponent(versionName).appendingPathExtension("mom")
        return NSManagedObjectModel(contentsOf: url)!
    }

    private func storeURL(from container: NSPersistentContainer) -> URL {
        let description = container.persistentStoreDescriptions.first!
        return description.url!
    }

    private func makeTemporaryStoreURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
    }
    
    // ---- original ----
    
    var cacheStore: PersistenceController!
    let fileManager = FileManager()
    static let bundleURL = Bundle(for: CoreDataMigrationTests.self).bundleURL

    override func setUpWithError() throws {
        try? fileManager.removeItem(at: Self.bundleURL.appendingPathComponent("Model.sqlite"))
        try fileManager.copyItem(at: Self.bundleURL.appendingPathComponent("Model.sqlite.v4.original"),
                                 to: Self.bundleURL.appendingPathComponent("Model.sqlite"))
    }

    override func tearDownWithError() throws {
        
        // remove all stores
        try cacheStore.managedObjectContext.persistentStoreCoordinator?.persistentStores.forEach { store in
            try cacheStore.managedObjectContext.persistentStoreCoordinator?.remove(store)
        }
        
        try fileManager.removeItem(at: Self.bundleURL.appendingPathComponent("Model.sqlite"))
        cacheStore = nil
    }

    func testV4toV5Migration() throws {
        let e = expectation(description: "\(#function): init")
        cacheStore = PersistenceController.init(directoryURL: Self.bundleURL)
        var error: Error?
        cacheStore.onReady {
            if let err = $0 {
                error = err
                XCTFail("Error opening \(Self.bundleURL): \(err)")
            }
            e.fulfill()
        }
        wait(for: [e], timeout: 10.0)
        if let error = error { throw error }        
        var entries: [CachedCarbObject]!
        let e0 = expectation(description: "\(#function): fetch")
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
        XCTAssertEqual(1, entries.count)
        
        // Do some spot checks.
        XCTAssertTrue(entityHasAttribute(entityName: "CachedGlucoseObject", attributeName: "device"))
        XCTAssertTrue(entityHasAttribute(entityName: "CachedGlucoseObject", attributeName: "trend"))
    }
    
    // TODO add func testV4toV5Migration()
    
    func entityHasAttribute(entityName: String, attributeName: String) -> Bool {
        XCTAssertNotNil(cacheStore.managedObjectContext.persistentStoreCoordinator?.managedObjectModel.entities)
        if let entities = cacheStore.managedObjectContext.persistentStoreCoordinator?.managedObjectModel.entities {
            for entity in entities {
                if entity.name == entityName, entity.attributesByName.contains(where: { (key: String, value: NSAttributeDescription) in
                    key == attributeName
                }) {
                    return true
                }
            }
        }
        return false
    }
}
