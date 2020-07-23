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
            observeHealthKitForCurrentAppOnly: false,
            cacheStore: cacheStore,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: .hours(24))
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
        let syncIdentifier = generateSyncIdentifier()
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3), syncIdentifier: syncIdentifier)
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let getCachedCarbSamplesCompletion = expectation(description: "Get cached carb samples completion")
        
        var handlerInvocation = 0
        
        var lastUUID: UUID?
        
        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1
            
            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].recordDate, addCarbEntry.recordDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertTrue(objects[0].isActive)
                    XCTAssertGreaterThan(objects[0].modificationCounter, 0)
                    lastUUID = objects[0].uuid
                    DispatchQueue.main.async {
                        carbStore.getCachedCarbSamples(start: Date().addingTimeInterval(-.minutes(1))) { (samples) in
                            getCachedCarbSamplesCompletion.fulfill()
                            XCTAssertEqual(samples.count, 1)
                            XCTAssertEqual(samples[0].recordDate, addCarbEntry.recordDate)
                            XCTAssertEqual(samples[0].absorptionTime, addCarbEntry.absorptionTime)
                            XCTAssertEqual(samples[0].createdByCurrentApp, true)
                            XCTAssertNil(samples[0].externalID)
                            XCTAssertEqual(samples[0].foodType, addCarbEntry.foodType)
                            XCTAssertEqual(samples[0].quantity, addCarbEntry.quantity)
                            XCTAssertEqual(samples[0].startDate, addCarbEntry.startDate)
                            XCTAssertEqual(samples[0].isUploaded, false)
                            XCTAssertEqual(samples[0].sampleUUID, lastUUID)
                            XCTAssertEqual(samples[0].syncIdentifier, syncIdentifier)
                            XCTAssertEqual(samples[0].syncVersion, 1)
                            XCTAssertTrue(samples[0].isActive)
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
        
        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, getCachedCarbSamplesCompletion], timeout: 2, enforceOrder: true)
    }
    
    func testAddAndReplaceCarbEntry() {
        let syncIdentifier = generateSyncIdentifier()
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3), syncIdentifier: syncIdentifier)
        let replaceCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: "Replace", absorptionTime: .hours(4))
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let replaceCarbEntryCompletion = expectation(description: "Replace carb entry completion")
        let replaceCarbEntryHandler = expectation(description: "Replace carb entry handler")
        let getCachedCarbSamplesCompletion = expectation(description: "Get cached carb samples completion")
        
        var handlerInvocation = 0
        
        var firstUUID: UUID?
        var secondUUID: UUID?
        var firstModificationCounter: Int64?
        
        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1
            
            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].recordDate, addCarbEntry.recordDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertTrue(objects[0].isActive)
                    XCTAssertGreaterThan(objects[0].modificationCounter, 0)
                    firstUUID = objects[0].uuid
                    firstModificationCounter = objects[0].modificationCounter
                    self.carbStore.replaceCarbEntry(StoredCarbEntry(managedObject: objects[0]), withEntry: replaceCarbEntry) { (result) in
                        replaceCarbEntryCompletion.fulfill()
                    }
                case 2:
                    replaceCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all().sorted { $0.syncVersion < $1.syncVersion }
                    XCTAssertEqual(objects.count, 2)
                    XCTAssertEqual(objects[0].recordDate, addCarbEntry.recordDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertEqual(objects[0].uuid!, firstUUID!)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertFalse(objects[0].isActive)
                    XCTAssertGreaterThan(objects[0].modificationCounter, firstModificationCounter!)
                    XCTAssertEqual(objects[1].recordDate, replaceCarbEntry.recordDate)
                    XCTAssertEqual(objects[1].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertNil(objects[1].externalID)
                    XCTAssertEqual(objects[1].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, replaceCarbEntry.startDate)
                    XCTAssertEqual(objects[1].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[1].uuid)
                    XCTAssertNotEqual(objects[1].uuid!, firstUUID!)
                    XCTAssertEqual(objects[1].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 2)
                    XCTAssertTrue(objects[1].isActive)
                    XCTAssertGreaterThan(objects[1].modificationCounter, firstModificationCounter!)
                    secondUUID = objects[1].uuid
                    DispatchQueue.main.async {
                        carbStore.getCachedCarbSamples(start: Date().addingTimeInterval(-.minutes(1))) { (samples) in
                            getCachedCarbSamplesCompletion.fulfill()
                            XCTAssertEqual(samples.count, 1)
                            XCTAssertEqual(samples[0].recordDate, replaceCarbEntry.recordDate)
                            XCTAssertEqual(samples[0].absorptionTime, replaceCarbEntry.absorptionTime)
                            XCTAssertEqual(samples[0].createdByCurrentApp, true)
                            XCTAssertNil(samples[0].externalID)
                            XCTAssertEqual(samples[0].foodType, replaceCarbEntry.foodType)
                            XCTAssertEqual(samples[0].quantity, replaceCarbEntry.quantity)
                            XCTAssertEqual(samples[0].startDate, replaceCarbEntry.startDate)
                            XCTAssertEqual(samples[0].isUploaded, false)
                            XCTAssertEqual(samples[0].sampleUUID, secondUUID)
                            XCTAssertEqual(samples[0].syncIdentifier, syncIdentifier)
                            XCTAssertEqual(samples[0].syncVersion, 2)
                            XCTAssertTrue(samples[0].isActive)
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
        
        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, replaceCarbEntryCompletion, replaceCarbEntryHandler, getCachedCarbSamplesCompletion], timeout: 2, enforceOrder: true)
    }
    
    func testAddAndDeleteCarbEntry() {
        let syncIdentifier = generateSyncIdentifier()
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3), syncIdentifier: syncIdentifier)
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let deleteCarbEntryCompletion = expectation(description: "Delete carb entry completion")
        let deleteCarbEntryHandler = expectation(description: "Delete carb entry handler")
        let getCachedCarbSamplesCompletion = expectation(description: "Get cached carb samples completion")
        
        var handlerInvocation = 0
        
        var lastUUID: UUID?
        var lastModificationCounter: Int64?
        
        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1
            
            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].recordDate, addCarbEntry.recordDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertTrue(objects[0].isActive)
                    XCTAssertGreaterThan(objects[0].modificationCounter, 0)
                    lastUUID = objects[0].uuid
                    lastModificationCounter = objects[0].modificationCounter
                    self.carbStore.deleteCarbEntry(StoredCarbEntry(managedObject: objects[0])) { (result) in
                        deleteCarbEntryCompletion.fulfill()
                    }
                case 2:
                    deleteCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].recordDate, addCarbEntry.recordDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertEqual(objects[0].uuid!, lastUUID!)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertFalse(objects[0].isActive)
                    XCTAssertGreaterThan(objects[0].modificationCounter, lastModificationCounter!)
                    DispatchQueue.main.async {
                        carbStore.getCachedCarbSamples(start: Date().addingTimeInterval(-.minutes(1))) { (samples) in
                            getCachedCarbSamplesCompletion.fulfill()
                            XCTAssertEqual(samples.count, 0)
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
        
        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, deleteCarbEntryCompletion, deleteCarbEntryHandler, getCachedCarbSamplesCompletion], timeout: 2, enforceOrder: true)
    }
    
    func testAddAndReplaceAndDeleteCarbEntry() {
        let syncIdentifier = generateSyncIdentifier()
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3), syncIdentifier: syncIdentifier)
        let replaceCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: "Replace", absorptionTime: .hours(4))
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let replaceCarbEntryCompletion = expectation(description: "Replace carb entry completion")
        let replaceCarbEntryHandler = expectation(description: "Replace carb entry handler")
        let deleteCarbEntryCompletion = expectation(description: "Delete carb entry completion")
        let deleteCarbEntryHandler = expectation(description: "Delete carb entry handler")
        let getCachedCarbSamplesCompletion = expectation(description: "Get cached carb samples completion")
        
        var handlerInvocation = 0
        
        var firstUUID: UUID?
        var secondUUID: UUID?
        var firstModificationCounter: Int64?
        var secondModificationCounter: Int64?
        
        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1
            
            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].recordDate, addCarbEntry.recordDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertTrue(objects[0].isActive)
                    XCTAssertGreaterThan(objects[0].modificationCounter, 0)
                    firstUUID = objects[0].uuid
                    firstModificationCounter = objects[0].modificationCounter
                    self.carbStore.replaceCarbEntry(StoredCarbEntry(managedObject: objects[0]), withEntry: replaceCarbEntry) { (result) in
                        replaceCarbEntryCompletion.fulfill()
                    }
                case 2:
                    replaceCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all().sorted { $0.syncVersion < $1.syncVersion }
                    XCTAssertEqual(objects.count, 2)
                    XCTAssertEqual(objects[0].recordDate, addCarbEntry.recordDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertEqual(objects[0].uuid!, firstUUID!)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertFalse(objects[0].isActive)
                    XCTAssertGreaterThan(objects[0].modificationCounter, firstModificationCounter!)
                    XCTAssertEqual(objects[1].recordDate, replaceCarbEntry.recordDate)
                    XCTAssertEqual(objects[1].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertNil(objects[1].externalID)
                    XCTAssertEqual(objects[1].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, replaceCarbEntry.startDate)
                    XCTAssertEqual(objects[1].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[1].uuid)
                    XCTAssertNotEqual(objects[1].uuid!, firstUUID!)
                    XCTAssertEqual(objects[1].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 2)
                    XCTAssertTrue(objects[1].isActive)
                    XCTAssertGreaterThan(objects[1].modificationCounter, firstModificationCounter!)
                    secondUUID = objects[1].uuid
                    firstModificationCounter = objects[0].modificationCounter
                    secondModificationCounter = objects[1].modificationCounter
                    self.carbStore.deleteCarbEntry(StoredCarbEntry(managedObject: objects[1])) { (result) in
                        deleteCarbEntryCompletion.fulfill()
                    }
                case 3:
                    deleteCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all().sorted { $0.syncVersion < $1.syncVersion }
                    XCTAssertEqual(objects.count, 2)
                    XCTAssertEqual(objects[0].recordDate, addCarbEntry.recordDate)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertEqual(objects[0].uuid!, firstUUID!)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertFalse(objects[0].isActive)
                    XCTAssertEqual(objects[0].modificationCounter, firstModificationCounter!)
                    XCTAssertEqual(objects[1].recordDate, replaceCarbEntry.recordDate)
                    XCTAssertEqual(objects[1].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertNil(objects[1].externalID)
                    XCTAssertEqual(objects[1].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, replaceCarbEntry.startDate)
                    XCTAssertEqual(objects[1].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[1].uuid)
                    XCTAssertEqual(objects[1].uuid!, secondUUID!)
                    XCTAssertEqual(objects[1].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 2)
                    XCTAssertFalse(objects[1].isActive)
                    XCTAssertGreaterThan(objects[1].modificationCounter, secondModificationCounter!)
                    DispatchQueue.main.async {
                        carbStore.getCachedCarbSamples(start: Date().addingTimeInterval(-.minutes(1))) { (samples) in
                            getCachedCarbSamplesCompletion.fulfill()
                            XCTAssertEqual(samples.count, 0)
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
        
        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, replaceCarbEntryCompletion, replaceCarbEntryHandler, deleteCarbEntryCompletion, deleteCarbEntryHandler, getCachedCarbSamplesCompletion], timeout: 2, enforceOrder: true)
    }
    
    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }
    
}

class CarbStoreQueryAnchorTests: XCTestCase {
    
    var rawValue: CarbStore.QueryAnchor.RawValue = [
        "modificationCounter": Int64(123)
    ]
    
    func testInitializerDefault() {
        let queryAnchor = CarbStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.modificationCounter, 0)
    }
    
    func testInitializerRawValue() {
        let queryAnchor = CarbStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.modificationCounter, 123)
    }
    
    func testInitializerRawValueMissingModificationCounter() {
        rawValue["modificationCounter"] = nil
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testInitializerRawValueInvalidModificationCounter() {
        rawValue["modificationCounter"] = "123"
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testRawValueWithDefault() {
        let rawValue = CarbStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(0))
    }
    
    func testRawValueWithNonDefault() {
        var queryAnchor = CarbStore.QueryAnchor()
        queryAnchor.modificationCounter = 123
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(123))
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
            observeHealthKitForCurrentAppOnly: false,
            cacheStore: cacheStore,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: .hours(24))
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
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
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
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.modificationCounter = 1
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 1)
                XCTAssertEqual(data.count, 0)
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
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 3)
                for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                    XCTAssertEqual(data[index].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(data[index].syncVersion, index)
                }
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDataWithStaleQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addData(withSyncIdentifiers: syncIdentifiers)
        
        queryAnchor.modificationCounter = 2
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 1)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(data[0].syncVersion, 2)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDataWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addData(withSyncIdentifiers: syncIdentifiers)
        
        queryAnchor.modificationCounter = 3
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 0)
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
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
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
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 2)
                XCTAssertEqual(data.count, 2)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(data[0].syncVersion, 0)
                XCTAssertEqual(data[1].syncIdentifier, syncIdentifiers[1])
                XCTAssertEqual(data[1].syncVersion, 1)
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
                cachedCarbObject.syncVersion = Int32(index)
                self.cacheStore.save()
            }
        }
    }
    
    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }
    
}
