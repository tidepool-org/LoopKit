//
//  CarbStoreTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import CoreData
@testable import LoopKit

class CarbStorePersistenceTests: PersistenceControllerTestCase, CarbStoreDelegate {
    
    var healthStore: HKHealthStoreMock!
    var carbStore: CarbStore!
    
    override func setUp() {
        super.setUp()

        healthStore = HKHealthStoreMock()
        carbStore = CarbStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: 0)
        carbStore.testQueryStore = healthStore
        carbStore.delegate = self
    }
    
    override func tearDown() {
        carbStore.delegate = nil
        carbStore = nil
        healthStore = nil
        
        carbStoreHasUpdatedCarbDataHandler = nil
        
        super.tearDown()
    }
    
    // MARK: - CarbStoreDelegate
    
    var carbStoreHasUpdatedCarbDataHandler: ((_ : CarbStore) -> Void)?
    
    func carbStoreHasUpdatedCarbData(_ carbStore: CarbStore) {
        carbStoreHasUpdatedCarbDataHandler?(carbStore)
    }
    
    func carbStore(_ carbStore: CarbStore, didError error: CarbStore.CarbStoreError) {}
    
    // MARK: -
    
    func testAddCarbEntry() {
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3))
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        var handlerInvocation = 0

        var firstSyncIdentifier: String?
        var firstUserCreatedDate: Date?

        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1

            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)

                    // Added object
                    XCTAssertNotNil(objects[0].userCreatedDate)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertNotNil(objects[0].syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNil(objects[0].removedDate)
                    XCTAssertGreaterThan(objects[0].anchorKey, 0)

                    firstSyncIdentifier = objects[0].syncIdentifier
                    firstUserCreatedDate = objects[0].userCreatedDate

                    DispatchQueue.main.async {
                        carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                            getCarbEntriesCompletion.fulfill()
                            switch result {
                            case .failure:
                                XCTFail("Unexpected failure")
                            case .success(let samples):
                                XCTAssertEqual(samples.count, 1)

                                // Added sample
                                XCTAssertEqual(samples[0].userCreatedDate, firstUserCreatedDate)
                                XCTAssertNil(samples[0].userUpdatedDate)
                                XCTAssertNil(samples[0].uuid)
                                XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                                XCTAssertEqual(samples[0].syncIdentifier, firstSyncIdentifier)
                                XCTAssertEqual(samples[0].syncVersion, 1)
                                XCTAssertEqual(samples[0].startDate, addCarbEntry.startDate)
                                XCTAssertEqual(samples[0].quantity, addCarbEntry.quantity)
                                XCTAssertEqual(samples[0].foodType, addCarbEntry.foodType)
                                XCTAssertEqual(samples[0].absorptionTime, addCarbEntry.absorptionTime)
                                XCTAssertEqual(samples[0].createdByCurrentApp, true)
                                XCTAssertNil(samples[0].externalID)
                            }
                        }
                    }
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }
        }

        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }

        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, getCarbEntriesCompletion], timeout: 2, enforceOrder: true)
    }

    func testAddAndReplaceCarbEntry() {
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3))
        let replaceCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: "Replace", absorptionTime: .hours(4))
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let replaceCarbEntryCompletion = expectation(description: "Replace carb entry completion")
        let replaceCarbEntryHandler = expectation(description: "Replace carb entry handler")
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        var handlerInvocation = 0

        var firstSyncIdentifier: String?
        var firstUserCreatedDate: Date?
        var firstAnchorKey: Int64?
        var secondUserUpdatedDate: Date?

        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1

            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)

                    // Added object
                    XCTAssertNotNil(objects[0].userCreatedDate)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertNotNil(objects[0].syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNil(objects[0].removedDate)
                    XCTAssertGreaterThan(objects[0].anchorKey, 0)

                    firstSyncIdentifier = objects[0].syncIdentifier
                    firstUserCreatedDate = objects[0].userCreatedDate
                    firstAnchorKey = objects[0].anchorKey

                    self.carbStore.replaceCarbEntry(StoredCarbEntry(managedObject: objects[0]), withEntry: replaceCarbEntry) { (result) in
                        replaceCarbEntryCompletion.fulfill()
                    }
                case 2:
                    replaceCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all().sorted { $0.syncVersion! < $1.syncVersion! }
                    XCTAssertEqual(objects.count, 2)

                    // Added object, removed
                    XCTAssertEqual(objects[0].userCreatedDate, firstUserCreatedDate)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertEqual(objects[0].syncIdentifier, firstSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNotNil(objects[0].removedDate)
                    XCTAssertEqual(objects[0].anchorKey, firstAnchorKey)

                    // Updated object
                    XCTAssertEqual(objects[1].userCreatedDate, firstUserCreatedDate)
                    XCTAssertNotNil(objects[1].userUpdatedDate)
                    XCTAssertNil(objects[1].userDeletedDate)
                    XCTAssertEqual(objects[1].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertNil(objects[1].externalID)
                    XCTAssertEqual(objects[1].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, replaceCarbEntry.startDate)
                    XCTAssertNil(objects[1].uuid)
                    XCTAssertEqual(objects[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertEqual(objects[1].syncIdentifier, firstSyncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 2)
                    XCTAssertEqual(objects[1].operation, .update)
                    XCTAssertNotNil(objects[1].addedDate)
                    XCTAssertNil(objects[1].removedDate)
                    XCTAssertGreaterThan(objects[1].anchorKey, firstAnchorKey!)

                    secondUserUpdatedDate = objects[1].userUpdatedDate

                    DispatchQueue.main.async {
                        carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                            getCarbEntriesCompletion.fulfill()
                            switch result {
                            case .failure:
                                XCTFail("Unexpected failure")
                            case .success(let samples):
                                XCTAssertEqual(samples.count, 1)

                                // Updated sample
                                XCTAssertEqual(samples[0].userCreatedDate, firstUserCreatedDate)
                                XCTAssertEqual(samples[0].userUpdatedDate, secondUserUpdatedDate)
                                XCTAssertNil(samples[0].uuid)
                                XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                                XCTAssertEqual(samples[0].syncIdentifier, firstSyncIdentifier)
                                XCTAssertEqual(samples[0].syncVersion, 2)
                                XCTAssertEqual(samples[0].startDate, replaceCarbEntry.startDate)
                                XCTAssertEqual(samples[0].quantity, replaceCarbEntry.quantity)
                                XCTAssertEqual(samples[0].foodType, replaceCarbEntry.foodType)
                                XCTAssertEqual(samples[0].absorptionTime, replaceCarbEntry.absorptionTime)
                                XCTAssertEqual(samples[0].createdByCurrentApp, true)
                                XCTAssertNil(samples[0].externalID)
                            }
                        }
                    }
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }
        }

        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }

        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, replaceCarbEntryCompletion, replaceCarbEntryHandler, getCarbEntriesCompletion], timeout: 2, enforceOrder: true)
    }

    func testAddAndDeleteCarbEntry() {
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3))
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let deleteCarbEntryCompletion = expectation(description: "Delete carb entry completion")
        let deleteCarbEntryHandler = expectation(description: "Delete carb entry handler")
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        var handlerInvocation = 0

        var firstSyncIdentifier: String?
        var firstUserCreatedDate: Date?
        var firstAnchorKey: Int64?

        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1

            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)

                    // Added object
                    XCTAssertNotNil(objects[0].userCreatedDate)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertNotNil(objects[0].syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNil(objects[0].removedDate)
                    XCTAssertGreaterThan(objects[0].anchorKey, 0)

                    firstSyncIdentifier = objects[0].syncIdentifier
                    firstUserCreatedDate = objects[0].userCreatedDate
                    firstAnchorKey = objects[0].anchorKey

                    self.carbStore.deleteCarbEntry(StoredCarbEntry(managedObject: objects[0])) { (result) in
                        deleteCarbEntryCompletion.fulfill()
                    }
                case 2:
                    deleteCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 2)

                    // Added object, removed
                    XCTAssertEqual(objects[0].userCreatedDate, firstUserCreatedDate)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertEqual(objects[0].syncIdentifier, firstSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNotNil(objects[0].removedDate)
                    XCTAssertEqual(objects[0].anchorKey, firstAnchorKey)

                    // Deleted object
                    XCTAssertEqual(objects[1].userCreatedDate, firstUserCreatedDate)
                    XCTAssertNil(objects[1].userUpdatedDate)
                    XCTAssertNotNil(objects[1].userDeletedDate)
                    XCTAssertEqual(objects[1].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertNil(objects[1].externalID)
                    XCTAssertEqual(objects[1].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[1].uuid)
                    XCTAssertEqual(objects[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertEqual(objects[1].syncIdentifier, firstSyncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 1)
                    XCTAssertEqual(objects[1].operation, .delete)
                    XCTAssertNotNil(objects[1].addedDate)
                    XCTAssertNil(objects[1].removedDate)
                    XCTAssertGreaterThan(objects[1].anchorKey, firstAnchorKey!)

                    DispatchQueue.main.async {
                        carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                            getCarbEntriesCompletion.fulfill()
                            switch result {
                            case .failure:
                                XCTFail("Unexpected failure")
                            case .success(let samples):
                                XCTAssertEqual(samples.count, 0)
                            }
                        }
                    }
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }

        }

        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }

        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, deleteCarbEntryCompletion, deleteCarbEntryHandler, getCarbEntriesCompletion], timeout: 2, enforceOrder: true)
    }

    func testAddAndReplaceAndDeleteCarbEntry() {
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3))
        let replaceCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: "Replace", absorptionTime: .hours(4))
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let replaceCarbEntryCompletion = expectation(description: "Replace carb entry completion")
        let replaceCarbEntryHandler = expectation(description: "Replace carb entry handler")
        let deleteCarbEntryCompletion = expectation(description: "Delete carb entry completion")
        let deleteCarbEntryHandler = expectation(description: "Delete carb entry handler")
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        var handlerInvocation = 0

        var firstSyncIdentifier: String?
        var firstUserCreatedDate: Date?
        var firstAnchorKey: Int64?
        var secondUserUpdatedDate: Date?
        var secondAnchorKey: Int64?

        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1

            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)

                    // Added object
                    XCTAssertNotNil(objects[0].userCreatedDate)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertNotNil(objects[0].syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNil(objects[0].removedDate)
                    XCTAssertGreaterThan(objects[0].anchorKey, 0)

                    firstSyncIdentifier = objects[0].syncIdentifier
                    firstUserCreatedDate = objects[0].userCreatedDate
                    firstAnchorKey = objects[0].anchorKey

                    self.carbStore.replaceCarbEntry(StoredCarbEntry(managedObject: objects[0]), withEntry: replaceCarbEntry) { (result) in
                        replaceCarbEntryCompletion.fulfill()
                    }
                case 2:
                    replaceCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all().sorted { $0.syncVersion! < $1.syncVersion! }
                    XCTAssertEqual(objects.count, 2)

                    // Added object, removed
                    XCTAssertEqual(objects[0].userCreatedDate, firstUserCreatedDate)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertEqual(objects[0].syncIdentifier, firstSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNotNil(objects[0].removedDate)
                    XCTAssertEqual(objects[0].anchorKey, firstAnchorKey)

                    // Updated object
                    XCTAssertEqual(objects[1].userCreatedDate, firstUserCreatedDate)
                    XCTAssertNotNil(objects[1].userUpdatedDate)
                    XCTAssertNil(objects[1].userDeletedDate)
                    XCTAssertEqual(objects[1].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertNil(objects[1].externalID)
                    XCTAssertEqual(objects[1].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, replaceCarbEntry.startDate)
                    XCTAssertNil(objects[1].uuid)
                    XCTAssertEqual(objects[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertEqual(objects[1].syncIdentifier, firstSyncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 2)
                    XCTAssertEqual(objects[1].operation, .update)
                    XCTAssertNotNil(objects[1].addedDate)
                    XCTAssertNil(objects[1].removedDate)
                    XCTAssertGreaterThan(objects[1].anchorKey, firstAnchorKey!)

                    secondUserUpdatedDate = objects[1].userUpdatedDate
                    secondAnchorKey = objects[1].anchorKey

                    self.carbStore.deleteCarbEntry(StoredCarbEntry(managedObject: objects[1])) { (result) in
                        deleteCarbEntryCompletion.fulfill()
                    }
                case 3:
                    deleteCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all().sorted { $0.syncVersion! < $1.syncVersion! }
                    XCTAssertEqual(objects.count, 3)

                    // Added object, removed
                    XCTAssertEqual(objects[0].userCreatedDate, firstUserCreatedDate)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertEqual(objects[0].syncIdentifier, firstSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNotNil(objects[0].removedDate)
                    XCTAssertEqual(objects[0].anchorKey, firstAnchorKey)

                    // Updated object, removed
                    XCTAssertEqual(objects[1].userCreatedDate, firstUserCreatedDate)
                    XCTAssertEqual(objects[1].userUpdatedDate, secondUserUpdatedDate)
                    XCTAssertNil(objects[1].userDeletedDate)
                    XCTAssertEqual(objects[1].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertNil(objects[1].externalID)
                    XCTAssertEqual(objects[1].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, replaceCarbEntry.startDate)
                    XCTAssertNil(objects[1].uuid)
                    XCTAssertEqual(objects[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertEqual(objects[1].syncIdentifier, firstSyncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 2)
                    XCTAssertEqual(objects[1].operation, .update)
                    XCTAssertNotNil(objects[1].addedDate)
                    XCTAssertNotNil(objects[1].removedDate)
                    XCTAssertEqual(objects[1].anchorKey, secondAnchorKey)

                    // Deleted object
                    XCTAssertEqual(objects[2].userCreatedDate, firstUserCreatedDate)
                    XCTAssertEqual(objects[2].userUpdatedDate, secondUserUpdatedDate)
                    XCTAssertNotNil(objects[2].userDeletedDate)
                    XCTAssertEqual(objects[2].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[2].createdByCurrentApp, true)
                    XCTAssertNil(objects[2].externalID)
                    XCTAssertEqual(objects[2].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[2].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[2].startDate, replaceCarbEntry.startDate)
                    XCTAssertNil(objects[2].uuid)
                    XCTAssertEqual(objects[2].provenanceIdentifier, HKSource.default().bundleIdentifier)
                    XCTAssertEqual(objects[2].syncIdentifier, firstSyncIdentifier)
                    XCTAssertEqual(objects[2].syncVersion, 2)
                    XCTAssertEqual(objects[2].operation, .delete)
                    XCTAssertNotNil(objects[2].addedDate)
                    XCTAssertNil(objects[2].removedDate)
                    XCTAssertGreaterThan(objects[2].anchorKey, secondAnchorKey!)

                    DispatchQueue.main.async {
                        carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                            getCarbEntriesCompletion.fulfill()
                            switch result {
                            case .failure:
                                XCTFail("Unexpected failure")
                            case .success(let samples):
                                XCTAssertEqual(samples.count, 0)
                            }
                        }
                    }
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }

        }

        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }

        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, replaceCarbEntryCompletion, replaceCarbEntryHandler, deleteCarbEntryCompletion, deleteCarbEntryHandler, getCarbEntriesCompletion], timeout: 2, enforceOrder: true)
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }

}

class CarbStoreQueryAnchorTests: XCTestCase {

    var rawValue: CarbStore.QueryAnchor.RawValue = [
        "anchorKey": Int64(123)
    ]

    func testInitializerDefault() {
        let queryAnchor = CarbStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.anchorKey, 0)
    }

    func testInitializerRawValue() {
        let queryAnchor = CarbStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.anchorKey, 123)
    }

    func testInitializerRawValueMissingAnchorKey() {
        rawValue["anchorKey"] = nil
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }

    func testInitializerRawValueInvalidAnchorKey() {
        rawValue["anchorKey"] = "123"
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }

    func testInitializerRawValueIgnoresDeprecatedStoredModificationCounter() {
        rawValue["storedModificationCounter"] = Int64(456)
        let queryAnchor = CarbStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.anchorKey, 123)
    }

    func testInitializerRawValueUsesDeprecatedStoredModificationCounter() {
        rawValue["anchorKey"] = nil
        rawValue["storedModificationCounter"] = Int64(456)
        let queryAnchor = CarbStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.anchorKey, 456)
    }

    func testRawValueWithDefault() {
        let rawValue = CarbStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["anchorKey"] as? Int64, Int64(0))
    }

    func testRawValueWithNonDefault() {
        var queryAnchor = CarbStore.QueryAnchor()
        queryAnchor.anchorKey = 123
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["anchorKey"] as? Int64, Int64(123))
    }

}

class CarbStoreQueryTests: PersistenceControllerTestCase {
    
    var carbStore: CarbStore!
    var completion: XCTestExpectation!
    var queryAnchor: CarbStore.QueryAnchor!
    var limit: Int!
    
    override func setUp() {
        super.setUp()
        
        carbStore = CarbStore(
            healthStore: HKHealthStoreMock(),
            cacheStore: cacheStore,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: 0)
        completion = expectation(description: "Completion")
        queryAnchor = CarbStore.QueryAnchor()
        limit = Int.max
    }
    
    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        carbStore = nil

        super.tearDown()
    }

    func testEmptyWithDefaultQueryAnchor() {
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 0)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testEmptyWithMissingQueryAnchor() {
        queryAnchor = nil

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 0)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.anchorKey = 1

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 1)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithUnusedQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 3)
                XCTAssertEqual(created.count, 1)
                XCTAssertEqual(created[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(created[0].syncVersion, 0)
                XCTAssertEqual(updated.count, 1)
                XCTAssertEqual(updated[0].syncIdentifier, syncIdentifiers[1])
                XCTAssertEqual(updated[0].syncVersion, 1)
                XCTAssertEqual(deleted.count, 1)
                XCTAssertEqual(deleted[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(deleted[0].syncVersion, 2)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithStaleQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.anchorKey = 2

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 3)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 1)
                XCTAssertEqual(deleted[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(deleted[0].syncVersion, 2)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.anchorKey = 3

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 3)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitZero() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        limit = 0

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 0)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitCoveredByData() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        limit = 2

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 2)
                XCTAssertEqual(created.count, 1)
                XCTAssertEqual(created[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(created[0].syncVersion, 0)
                XCTAssertEqual(updated.count, 1)
                XCTAssertEqual(updated[0].syncIdentifier, syncIdentifiers[1])
                XCTAssertEqual(updated[0].syncVersion, 1)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    private func addData(withSyncIdentifiers syncIdentifiers: [String]) {
        cacheStore.managedObjectContext.performAndWait {
            for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                let cachedCarbObject = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                cachedCarbObject.createdByCurrentApp = true
                cachedCarbObject.startDate = Date()
                cachedCarbObject.uuid = UUID()
                cachedCarbObject.syncIdentifier = syncIdentifier
                cachedCarbObject.syncVersion = index
                cachedCarbObject.operation = Operation(rawValue: index % Operation.allCases.count)!
                cachedCarbObject.addedDate = Date()
                self.cacheStore.save()
            }
        }
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }
    
}
