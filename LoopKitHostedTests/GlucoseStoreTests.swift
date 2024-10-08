//
//  GlucoseStoreTests.swift
//  LoopKitHostedTests
//
//  Created by Darin Krauss on 10/12/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class GlucoseStoreTestsBase: PersistenceControllerTestCase, GlucoseStoreDelegate {
    private static let device = HKDevice(name: "NAME", manufacturer: "MANUFACTURER", model: "MODEL", hardwareVersion: "HARDWAREVERSION", firmwareVersion: "FIRMWAREVERSION", softwareVersion: "SOFTWAREVERSION", localIdentifier: "LOCALIDENTIFIER", udiDeviceIdentifier: "UDIDEVICEIDENTIFIER")
    internal let sample1 = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.minutes(6)),
                                            quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4),
                                            condition: nil,
                                            trend: nil,
                                            trendRate: nil,
                                            isDisplayOnly: true,
                                            wasUserEntered: false,
                                            syncIdentifier: "1925558F-E98F-442F-BBA6-F6F75FB4FD91",
                                            syncVersion: 2,
                                            device: device)
    internal let sample2 = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.minutes(2)),
                                            quantity: HKQuantity(unit: .millimolesPerLiter, doubleValue: 7.4),
                                            condition: nil,
                                            trend: .flat,
                                            trendRate: HKQuantity(unit: .millimolesPerLiterPerMinute, doubleValue: 0.0),
                                            isDisplayOnly: false,
                                            wasUserEntered: true,
                                            syncIdentifier: "535F103C-3DFE-48F2-B15A-47313191E7B7",
                                            syncVersion: 3,
                                            device: device)
    internal let sample3 = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.minutes(4)),
                                            quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 400.0),
                                            condition: .aboveRange,
                                            trend: .upUpUp,
                                            trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 4.2),
                                            isDisplayOnly: false,
                                            wasUserEntered: false,
                                            syncIdentifier: "E1624D2B-A971-41B8-B8A0-3A8212AC3D71",
                                            syncVersion: 4,
                                            device: device)

    var mockHealthStore: HKHealthStoreMock!
    var glucoseStore: GlucoseStore!
    var hkSampleStore: HealthKitSampleStore!
    var delegateCompletion: XCTestExpectation?
    var authorizationStatus: HKAuthorizationStatus = .notDetermined

    override func setUp() async throws {
        try await super.setUp()

        mockHealthStore = HKHealthStoreMock()

        hkSampleStore = HealthKitSampleStore(healthStore: mockHealthStore, type: HealthKitSampleStore.glucoseType)
        hkSampleStore.observerQueryType = MockHKObserverQuery.self
        hkSampleStore.anchoredObjectQueryType = MockHKAnchoredObjectQuery.self

        mockHealthStore.authorizationStatus = authorizationStatus
        glucoseStore = GlucoseStore(healthKitSampleStore: hkSampleStore,
                                    cacheStore: cacheStore,
                                    cacheLength: .hours(1),
                                    provenanceIdentifier: HKSource.default().bundleIdentifier)
        glucoseStore.delegate = self
    }

    override func tearDown() async throws {
        try await glucoseStore.purgeAllGlucose(for: HKSource.default())

        delegateCompletion = nil
        glucoseStore = nil
        mockHealthStore = nil

        try await super.tearDown()
    }

    // MARK: - GlucoseStoreDelegate

    func glucoseStoreHasUpdatedGlucoseData(_ glucoseStore: GlucoseStore) {
        delegateCompletion?.fulfill()
    }
}

class GlucoseStoreTestsAuthorizationRequired: GlucoseStoreTestsBase {
    func testObserverQueryStartup() {
        XCTAssert(hkSampleStore.authorizationRequired);
        XCTAssertNil(hkSampleStore.observerQuery);

        mockHealthStore.observerQueryStartedExpectation = expectation(description: "observer query started")

        mockHealthStore.authorizationStatus = .sharingAuthorized
        hkSampleStore.authorizationIsDetermined()

        waitForExpectations(timeout: 3)

        XCTAssertNotNil(hkSampleStore.observerQuery);
    }
}

class GlucoseStoreTestsAuthorized: GlucoseStoreTestsBase {
    override func setUp() async throws {
        authorizationStatus = .sharingAuthorized
        try await super.setUp()
    }

    func testObserverQueryStartup() {
        // Check that an observer query is registered when authorization is already determined.
        XCTAssertFalse(hkSampleStore.authorizationRequired);

        mockHealthStore.observerQueryStartedExpectation = expectation(description: "observer query started")

        waitForExpectations(timeout: 30)

        XCTAssertNotNil(hkSampleStore.observerQuery)
    }
}

class GlucoseStoreTestSharingUndetermined: GlucoseStoreTestsBase {
    func testHealthKitQueryAnchorPersistence() {
        XCTAssert(hkSampleStore.authorizationRequired);
        XCTAssertNil(hkSampleStore.observerQuery);

        mockHealthStore.observerQueryStartedExpectation = expectation(description: "observer query started")

        mockHealthStore.authorizationStatus = .sharingAuthorized
        hkSampleStore.authorizationIsDetermined()

        waitForExpectations(timeout: 3)

        XCTAssertNotNil(mockHealthStore.observerQuery)

        mockHealthStore.anchorQueryStartedExpectation = expectation(description: "anchored object query started")

        let observerQueryCompletionExpectation = expectation(description: "observer query completion")

        let observerQueryCompletionHandler = {
            observerQueryCompletionExpectation.fulfill()
        }

        let mockObserverQuery = mockHealthStore.observerQuery as! MockHKObserverQuery

        // This simulates a signal marking the arrival of new HK Data.
        mockObserverQuery.updateHandler?(mockObserverQuery, observerQueryCompletionHandler, nil)

        wait(for: [mockHealthStore.anchorQueryStartedExpectation!])

        let currentAnchor = HKQueryAnchor(fromValue: 5)

        let mockAnchoredObjectQuery = mockHealthStore.anchoredObjectQuery as! MockHKAnchoredObjectQuery
        mockAnchoredObjectQuery.resultsHandler?(mockAnchoredObjectQuery, [], [], currentAnchor, nil)

        // Wait for observerQueryCompletionExpectation
        waitForExpectations(timeout: 3)

        XCTAssertNotNil(hkSampleStore.queryAnchor)

        cacheStore.managedObjectContext.performAndWait {}

        // Create a new carb store, and ensure it uses the last query anchor

        let newSampleStore = HealthKitSampleStore(healthStore: mockHealthStore, type: HealthKitSampleStore.glucoseType)
        newSampleStore.observerQueryType = MockHKObserverQuery.self
        newSampleStore.anchoredObjectQueryType = MockHKAnchoredObjectQuery.self

        // Create a new glucose store, and ensure it uses the last query anchor
        let _ = GlucoseStore(healthKitSampleStore: newSampleStore,
                             cacheStore: cacheStore,
                             provenanceIdentifier: HKSource.default().bundleIdentifier)

        mockHealthStore.observerQueryStartedExpectation = expectation(description: "new observer query started")

        mockHealthStore.authorizationStatus = .sharingAuthorized
        newSampleStore.authorizationIsDetermined()

        // Wait for observerQueryCompletionExpectation
        waitForExpectations(timeout: 3)

        mockHealthStore.anchorQueryStartedExpectation = expectation(description: "new anchored object query started")

        let mockObserverQuery2 = mockHealthStore.observerQuery as! MockHKObserverQuery

        // This simulates a signal marking the arrival of new HK Data.
        mockObserverQuery2.updateHandler?(mockObserverQuery2, {}, nil)

        // Wait for anchorQueryStartedExpectation
        waitForExpectations(timeout: 3)

        // Assert new carb store is querying with the last anchor that our HealthKit mock returned
        let mockAnchoredObjectQuery2 = mockHealthStore.anchoredObjectQuery as! MockHKAnchoredObjectQuery
        XCTAssertEqual(currentAnchor, mockAnchoredObjectQuery2.anchor)


        mockAnchoredObjectQuery2.resultsHandler?(mockAnchoredObjectQuery2, [], [], currentAnchor, nil)
    }
}


class GlucoseStoreTests: GlucoseStoreTestsBase {
    override func setUp() async throws {
        authorizationStatus = .sharingAuthorized
        try await super.setUp()
    }

    // MARK: - Fetching

    func testGetGlucoseSamples() async throws {
        var samples = try await glucoseStore.addGlucoseSamples([sample1, sample2, sample3])
        XCTAssertEqual(samples.count, 3)

        await glucoseStore.saveSamplesToHealthKit()

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 3)
        XCTAssertNotNil(samples[0].uuid)
        XCTAssertNil(samples[0].healthKitEligibleDate)
        assertEqualSamples(samples[0], self.sample1)
        XCTAssertNotNil(samples[1].uuid)
        XCTAssertNil(samples[1].healthKitEligibleDate)
        assertEqualSamples(samples[1], self.sample3)
        XCTAssertNotNil(samples[2].uuid)
        XCTAssertNil(samples[2].healthKitEligibleDate)
        assertEqualSamples(samples[2], self.sample2)

        samples = try await glucoseStore.getGlucoseSamples(
            start: Date(timeIntervalSinceNow: -.minutes(5)),
            end: Date(timeIntervalSinceNow: -.minutes(3))
        )
        XCTAssertEqual(samples.count, 1)
        XCTAssertNotNil(samples[0].uuid)
        XCTAssertNil(samples[0].healthKitEligibleDate)
        assertEqualSamples(samples[0], self.sample3)

        try await glucoseStore.purgeCachedGlucoseObjects()

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 0)
    }
    
    enum Error: Swift.Error { case arbitrary }

    func testGetGlucoseSamplesDelayedHealthKitStorage() async throws {
        glucoseStore.healthKitStorageDelay = .minutes(5)
        var hkobjects = [HKObject]()
        mockHealthStore.setSaveHandler { o, _, _ in hkobjects = o }
        var samples = try await glucoseStore.addGlucoseSamples([sample1, sample2, sample3])
        XCTAssertEqual(samples.count, 3)

        await glucoseStore.saveSamplesToHealthKit()

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 3)
        // HealthKit storage is deferred, so the second 1 UUIDs is nil
        XCTAssertNotNil(samples[0].uuid)
        XCTAssertNil(samples[0].healthKitEligibleDate)
        assertEqualSamples(samples[0], self.sample1)
        XCTAssertNil(samples[1].uuid)
        XCTAssertNotNil(samples[1].healthKitEligibleDate)
        assertEqualSamples(samples[1], self.sample3)
        XCTAssertNotNil(samples[2].uuid)
        XCTAssertNil(samples[2].healthKitEligibleDate)
        assertEqualSamples(samples[2], self.sample2)

        let stored = hkobjects[0] as! HKQuantitySample
        XCTAssertEqual(sample1.quantitySample.quantity, stored.quantity)
    }
    
    func testGetGlucoseSamplesErrorHealthKitStorage() async throws {
        mockHealthStore.saveError = Error.arbitrary
        var hkobjects = [HKObject]()
        mockHealthStore.setSaveHandler { o, _, _ in hkobjects = o }

        var samples = try await glucoseStore.addGlucoseSamples([sample1, sample2, sample3])
        XCTAssertEqual(samples.count, 3)

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 3)
        // HealthKit storage is deferred, so the second 2 UUIDs are nil
        XCTAssertNil(samples[0].uuid)
        XCTAssertNotNil(samples[0].healthKitEligibleDate)
        assertEqualSamples(samples[0], self.sample1)
        XCTAssertNil(samples[1].uuid)
        XCTAssertNotNil(samples[1].healthKitEligibleDate)
        assertEqualSamples(samples[1], self.sample3)
        XCTAssertNil(samples[2].uuid)
        XCTAssertNotNil(samples[2].healthKitEligibleDate)
        assertEqualSamples(samples[2], self.sample2)

        XCTAssertEqual(3, hkobjects.count)
    }

    func testGetGlucoseSamplesDeniedHealthKitStorage() {
        mockHealthStore.authorizationStatus = .sharingDenied
        var hkobjects = [HKObject]()
        mockHealthStore.setSaveHandler { o, _, _ in hkobjects = o }
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 30)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                // HealthKit storage is denied, so all UUIDs are nil
                XCTAssertNil(samples[0].uuid)
                XCTAssertNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample1)
                XCTAssertNil(samples[1].uuid)
                XCTAssertNil(samples[1].healthKitEligibleDate)
                assertEqualSamples(samples[1], self.sample3)
                XCTAssertNil(samples[2].uuid)
                XCTAssertNil(samples[2].healthKitEligibleDate)
                assertEqualSamples(samples[2], self.sample2)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 30)

        XCTAssertTrue(hkobjects.isEmpty)
    }
    
    func testGetGlucoseSamplesSomeDeniedHealthKitStorage() async throws {
        glucoseStore.healthKitStorageDelay = 0
        var hkobjects = [HKObject]()
        mockHealthStore.setSaveHandler { o, _, _ in hkobjects = o }

        // Authorized
        var samples = try await glucoseStore.addGlucoseSamples([sample1])
        await glucoseStore.saveSamplesToHealthKit()
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(1, hkobjects.count)
        hkobjects = []
        
        mockHealthStore.authorizationStatus = .sharingDenied
        // Denied
        samples = try await glucoseStore.addGlucoseSamples([sample2])
        await glucoseStore.saveSamplesToHealthKit()
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(0, hkobjects.count)
        hkobjects = []

        mockHealthStore.authorizationStatus = .sharingAuthorized
        // Authorized
        samples = try await glucoseStore.addGlucoseSamples([sample3])
        await glucoseStore.saveSamplesToHealthKit()
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(1, hkobjects.count)
        hkobjects = []

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 3)
        XCTAssertNotNil(samples[0].uuid)
        XCTAssertNil(samples[0].healthKitEligibleDate)
        assertEqualSamples(samples[0], self.sample1)
        XCTAssertNotNil(samples[1].uuid)
        XCTAssertNil(samples[1].healthKitEligibleDate)
        assertEqualSamples(samples[1], self.sample3)
        XCTAssertNil(samples[2].uuid)
        XCTAssertNil(samples[2].healthKitEligibleDate)
        assertEqualSamples(samples[2], self.sample2)
    }
    
    func testLatestGlucose() {
        XCTAssertNil(glucoseStore.latestGlucose)

        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                assertEqualSamples(samples[0], self.sample1)
                assertEqualSamples(samples[1], self.sample2)
                assertEqualSamples(samples[2], self.sample3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 30)

        XCTAssertNotNil(glucoseStore.latestGlucose)
        XCTAssertEqual(glucoseStore.latestGlucose?.startDate, sample2.date)
        XCTAssertEqual(glucoseStore.latestGlucose?.endDate, sample2.date)
        XCTAssertEqual(glucoseStore.latestGlucose?.quantity, sample2.quantity)
        XCTAssertEqual(glucoseStore.latestGlucose?.provenanceIdentifier, HKSource.default().bundleIdentifier)
        XCTAssertEqual(glucoseStore.latestGlucose?.isDisplayOnly, sample2.isDisplayOnly)
        XCTAssertEqual(glucoseStore.latestGlucose?.wasUserEntered, sample2.wasUserEntered)

        let purgeCachedGlucoseObjectsCompletion = expectation(description: "purgeCachedGlucoseObjects")
        glucoseStore.purgeCachedGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeCachedGlucoseObjectsCompletion.fulfill()
        }
        waitForExpectations(timeout: 30)

        XCTAssertNil(glucoseStore.latestGlucose)
    }

    // MARK: - Modification

    func testAddGlucoseSamples() async throws {
        var samples = try await glucoseStore.addGlucoseSamples([sample1, sample2, sample3, sample1, sample2, sample3])
        XCTAssertEqual(samples.count, 3)
        // Note: the HealthKit UUID is no longer updated before being returned as a result of addGlucoseSamples.
        XCTAssertNil(samples[0].uuid)
        XCTAssertNotNil(samples[0].healthKitEligibleDate)
        assertEqualSamples(samples[0], self.sample1)
        XCTAssertNil(samples[1].uuid)
        XCTAssertNotNil(samples[1].healthKitEligibleDate)
        assertEqualSamples(samples[1], self.sample2)
        XCTAssertNil(samples[2].uuid)
        XCTAssertNotNil(samples[2].healthKitEligibleDate)
        assertEqualSamples(samples[2], self.sample3)

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 3)
        XCTAssertNotNil(samples[0].uuid)
        XCTAssertNil(samples[0].healthKitEligibleDate)
        assertEqualSamples(samples[0], self.sample1)
        XCTAssertNotNil(samples[1].uuid)
        XCTAssertNil(samples[1].healthKitEligibleDate)
        assertEqualSamples(samples[1], self.sample3)
        XCTAssertNotNil(samples[2].uuid)
        XCTAssertNil(samples[2].healthKitEligibleDate)
        assertEqualSamples(samples[2], self.sample2)

        samples = try await glucoseStore.addGlucoseSamples([sample3, sample1, sample2])
        XCTAssertEqual(samples.count, 0)

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 3)
        XCTAssertNotNil(samples[0].uuid)
        XCTAssertNil(samples[0].healthKitEligibleDate)
        assertEqualSamples(samples[0], self.sample1)
        XCTAssertNotNil(samples[1].uuid)
        XCTAssertNil(samples[1].healthKitEligibleDate)
        assertEqualSamples(samples[1], self.sample3)
        XCTAssertNotNil(samples[2].uuid)
        XCTAssertNil(samples[2].healthKitEligibleDate)
        assertEqualSamples(samples[2], self.sample2)
    }

    func testAddGlucoseSamplesEmpty() {
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 30)
    }

    func testAddGlucoseSamplesNotification() {
        delegateCompletion = expectation(description: "delegate")
        let glucoseSamplesDidChangeCompletion = expectation(description: "glucoseSamplesDidChange")
        let observer = NotificationCenter.default.addObserver(forName: GlucoseStore.glucoseSamplesDidChange, object: glucoseStore, queue: nil) { notification in
            glucoseSamplesDidChangeCompletion.fulfill()
        }

        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        wait(for: [glucoseSamplesDidChangeCompletion, delegateCompletion!, addGlucoseSamplesCompletion], timeout: 30, enforceOrder: true)

        NotificationCenter.default.removeObserver(observer)
        delegateCompletion = nil
    }

    // MARK: - Watch Synchronization

    func testSyncGlucoseSamples() async throws {
        var syncGlucoseSamples: [StoredGlucoseSample] = []

        var samples = try await glucoseStore.addGlucoseSamples([sample1, sample2, sample3])
        XCTAssertEqual(samples.count, 3)

        await glucoseStore.saveSamplesToHealthKit()

        var objects = try await glucoseStore.getSyncGlucoseSamples()
        XCTAssertEqual(objects.count, 3)
        XCTAssertNotNil(objects[0].uuid)
        assertEqualSamples(objects[0], self.sample1)
        XCTAssertNotNil(objects[1].uuid)
        assertEqualSamples(objects[1], self.sample3)
        XCTAssertNotNil(objects[2].uuid)
        assertEqualSamples(objects[2], self.sample2)
        syncGlucoseSamples = objects

        objects = try await glucoseStore.getSyncGlucoseSamples(
            start: Date(timeIntervalSinceNow: -.minutes(5)),
            end: Date(timeIntervalSinceNow: -.minutes(3))
        )
        XCTAssertEqual(objects.count, 1)
        XCTAssertNotNil(objects[0].uuid)
        assertEqualSamples(objects[0], self.sample3)

        try await glucoseStore.purgeCachedGlucoseObjects()

        samples = try await glucoseStore.getSyncGlucoseSamples()
        XCTAssertEqual(samples.count, 0)

        try await glucoseStore.setSyncGlucoseSamples(syncGlucoseSamples)

        objects = try await glucoseStore.getSyncGlucoseSamples()
        XCTAssertEqual(objects.count, 3)
        XCTAssertNotNil(objects[0].uuid)
        assertEqualSamples(objects[0], self.sample1)
        XCTAssertNotNil(objects[1].uuid)
        assertEqualSamples(objects[1], self.sample3)
        XCTAssertNotNil(objects[2].uuid)
        assertEqualSamples(objects[2], self.sample2)
        syncGlucoseSamples = objects
    }

    // MARK: - Cache Management

    func testEarliestCacheDate() {
        XCTAssertEqual(glucoseStore.earliestCacheDate.timeIntervalSinceNow, -.hours(1), accuracy: 1)
    }

    func testPurgeAllGlucoseSamples() async throws {
        var samples = try await glucoseStore.addGlucoseSamples([sample1, sample2, sample3])
        XCTAssertEqual(samples.count, 3)

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 3)

        try await glucoseStore.purgeAllGlucose(for: HKSource.default())

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 0)
    }

    func testPurgeExpiredGlucoseObjects() {
        let expiredSample = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.hours(2)),
                                             quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 198.7),
                                             condition: nil,
                                             trend: nil,
                                             trendRate: nil,
                                             isDisplayOnly: false,
                                             wasUserEntered: false,
                                             syncIdentifier: "6AB8C7F3-A2CE-442F-98C4-3D0514626B5F",
                                             syncVersion: 3)

        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3, expiredSample]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 4)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 30)

        let getGlucoseSamplesCompletion = expectation(description: "getGlucoseSamples")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            getGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 30)
    }

    func testPurgeCachedGlucoseObjects() async throws {
        var samples = try await glucoseStore.addGlucoseSamples([sample1, sample2, sample3])
        XCTAssertEqual(samples.count, 3)

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 3)

        try await glucoseStore.purgeCachedGlucoseObjects(before: Date(timeIntervalSinceNow: -.minutes(5)))

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 2)

        try await glucoseStore.purgeCachedGlucoseObjects()

        samples = try await glucoseStore.getGlucoseSamples()
        XCTAssertEqual(samples.count, 0)
    }

    func testPurgeCachedGlucoseObjectsNotification() {
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 30)

        delegateCompletion = expectation(description: "delegate")
        let glucoseSamplesDidChangeCompletion = expectation(description: "glucoseSamplesDidChange")
        let observer = NotificationCenter.default.addObserver(forName: GlucoseStore.glucoseSamplesDidChange, object: glucoseStore, queue: nil) { notification in
            glucoseSamplesDidChangeCompletion.fulfill()
        }

        let purgeCachedGlucoseObjectsCompletion = expectation(description: "purgeCachedGlucoseObjects")
        glucoseStore.purgeCachedGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeCachedGlucoseObjectsCompletion.fulfill()

        }
        wait(for: [glucoseSamplesDidChangeCompletion, delegateCompletion!, purgeCachedGlucoseObjectsCompletion], timeout: 30, enforceOrder: true)

        NotificationCenter.default.removeObserver(observer)
        delegateCompletion = nil
    }
}

fileprivate func assertEqualSamples(_ storedGlucoseSample: StoredGlucoseSample,
                                    _ newGlucoseSample: NewGlucoseSample,
                                    provenanceIdentifier: String = HKSource.default().bundleIdentifier,
                                    file: StaticString = #file,
                                    line: UInt = #line) {
    XCTAssertEqual(storedGlucoseSample.provenanceIdentifier, provenanceIdentifier, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.syncIdentifier, newGlucoseSample.syncIdentifier, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.syncVersion, newGlucoseSample.syncVersion, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.startDate, newGlucoseSample.date, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.quantity, newGlucoseSample.quantity, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.isDisplayOnly, newGlucoseSample.isDisplayOnly, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.wasUserEntered, newGlucoseSample.wasUserEntered, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.device, newGlucoseSample.device, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.condition, newGlucoseSample.condition, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.trend, newGlucoseSample.trend, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.trendRate, newGlucoseSample.trendRate, file: file, line: line)
}
