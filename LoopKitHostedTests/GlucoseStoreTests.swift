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

class GlucoseStoreTests: PersistenceControllerTestCase, GlucoseStoreDelegate {
    private let sample1 = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.minutes(6)),
                                           quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4),
                                           isDisplayOnly: true,
                                           wasUserEntered: false,
                                           syncIdentifier: "1925558F-E98F-442F-BBA6-F6F75FB4FD91",
                                           syncVersion: 2)
    private let sample2 = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.minutes(2)),
                                           quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 134.5),
                                           isDisplayOnly: false,
                                           wasUserEntered: true,
                                           syncIdentifier: "535F103C-3DFE-48F2-B15A-47313191E7B7",
                                           syncVersion: 3)
    private let sample3 = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.minutes(4)),
                                           quantity: HKQuantity(unit: .millimolesPerLiter, doubleValue: 7.65),
                                           isDisplayOnly: false,
                                           wasUserEntered: false,
                                           syncIdentifier: "E1624D2B-A971-41B8-B8A0-3A8212AC3D71",
                                           syncVersion: 4)

    var healthStore: HKHealthStoreMock!
    var glucoseStore: GlucoseStore!
    var delegateCompletion: XCTestExpectation?

    override func setUp() {
        super.setUp()

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { error in
            XCTAssertNil(error)
            semaphore.signal()
        }
        semaphore.wait()

        healthStore = HKHealthStoreMock()
        glucoseStore = GlucoseStore(healthStore: healthStore,
                                    cacheStore: cacheStore,
                                    cacheLength: .hours(1),
                                    observationInterval: .minutes(30),
                                    provenanceIdentifier: HKSource.default().bundleIdentifier)
        glucoseStore.delegate = self
    }

    override func tearDown() {
        let semaphore = DispatchSemaphore(value: 0)
        glucoseStore.purgeAllGlucoseSamples(healthKitPredicate: HKQuery.predicateForObjects(from: HKSource.default())) { error in
            XCTAssertNil(error)
            semaphore.signal()
        }
        semaphore.wait()

        delegateCompletion = nil
        glucoseStore = nil
        healthStore = nil

        super.tearDown()
    }

    // MARK: - GlucoseStoreDelegate

    func glucoseStoreHasUpdatedGlucoseData(_ glucoseStore: GlucoseStore) {
        delegateCompletion?.fulfill()
    }

    // MARK: - HealthKitSampleStore

    func testHealthKitQueryAnchorPersistence() {
        var observerQuery: HKObserverQueryMock? = nil
        var anchoredObjectQuery: HKAnchoredObjectQueryMock? = nil

        glucoseStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            return observerQuery!
        }

        let authorizationCompletion = expectation(description: "authorization completion")
        glucoseStore.authorize { (result) in
            authorizationCompletion.fulfill()
        }

        waitForExpectations(timeout: 3)

        XCTAssertNotNil(observerQuery)

        let anchoredObjectQueryCreationExpectation = expectation(description: "anchored object query creation")
        glucoseStore.createAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) -> HKAnchoredObjectQuery in
            anchoredObjectQuery = HKAnchoredObjectQueryMock(type: sampleType, predicate: predicate, anchor: anchor, limit: limit, resultsHandler: resultsHandler)
            anchoredObjectQueryCreationExpectation.fulfill()
            return anchoredObjectQuery!
        }

        let observerQueryCompletionExpectation = expectation(description: "observer query completion")

        let observerQueryCompletionHandler = {
            observerQueryCompletionExpectation.fulfill()
        }
        // This simulates a signal marking the arrival of new HK Data.
        observerQuery!.updateHandler(observerQuery!, observerQueryCompletionHandler, nil)

        wait(for: [anchoredObjectQueryCreationExpectation], timeout: 3)

        // Trigger results handler for anchored object query
        let returnedAnchor = HKQueryAnchor(fromValue: 5)
        anchoredObjectQuery!.resultsHandler(anchoredObjectQuery!, [], [], returnedAnchor, nil)

        // Wait for observerQueryCompletionExpectation
        waitForExpectations(timeout: 3)

        XCTAssertNotNil(glucoseStore.queryAnchor)

        cacheStore.managedObjectContext.performAndWait {}

        // Create a new glucose store, and ensure it uses the last query anchor
        let newGlucoseStore = GlucoseStore(healthStore: healthStore,
                                           cacheStore: cacheStore,
                                           provenanceIdentifier: HKSource.default().bundleIdentifier)

        let newAuthorizationCompletion = expectation(description: "authorization completion")

        observerQuery = nil

        newGlucoseStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            return observerQuery!
        }

        newGlucoseStore.authorize { (result) in
            newAuthorizationCompletion.fulfill()
        }
        waitForExpectations(timeout: 3)

        anchoredObjectQuery = nil

        let newAnchoredObjectQueryCreationExpectation = expectation(description: "new anchored object query creation")
        newGlucoseStore.createAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) -> HKAnchoredObjectQuery in
            anchoredObjectQuery = HKAnchoredObjectQueryMock(type: sampleType, predicate: predicate, anchor: anchor, limit: limit, resultsHandler: resultsHandler)
            newAnchoredObjectQueryCreationExpectation.fulfill()
            return anchoredObjectQuery!
        }

        // This simulates a signal marking the arrival of new HK Data.
        observerQuery!.updateHandler(observerQuery!, {}, nil)

        wait(for: [newAnchoredObjectQueryCreationExpectation], timeout: 3)

        // Assert new glucose store is querying with the last anchor that our HealthKit mock returned
        XCTAssertEqual(returnedAnchor, anchoredObjectQuery?.anchor)

        anchoredObjectQuery!.resultsHandler(anchoredObjectQuery!, [], [], returnedAnchor, nil)
    }

    // MARK: - Fetching

    func testGetGlucoseSamples() {
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
        wait(for: [addGlucoseSamplesCompletion], timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertEqual(samples[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[0].syncIdentifier, self.sample1.syncIdentifier)
                XCTAssertEqual(samples[0].syncVersion, self.sample1.syncVersion)
                XCTAssertEqual(samples[0].startDate, self.sample1.date)
                XCTAssertEqual(samples[0].quantity, self.sample1.quantity)
                XCTAssertEqual(samples[0].isDisplayOnly, self.sample1.isDisplayOnly)
                XCTAssertEqual(samples[0].wasUserEntered, self.sample1.wasUserEntered)
                XCTAssertNotNil(samples[1].uuid)
                XCTAssertEqual(samples[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[1].syncIdentifier, self.sample3.syncIdentifier)
                XCTAssertEqual(samples[1].syncVersion, self.sample3.syncVersion)
                XCTAssertEqual(samples[1].startDate, self.sample3.date)
                XCTAssertEqual(samples[1].quantity, self.sample3.quantity)
                XCTAssertEqual(samples[1].isDisplayOnly, self.sample3.isDisplayOnly)
                XCTAssertEqual(samples[1].wasUserEntered, self.sample3.wasUserEntered)
                XCTAssertNotNil(samples[2].uuid)
                XCTAssertEqual(samples[2].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[2].syncIdentifier, self.sample2.syncIdentifier)
                XCTAssertEqual(samples[2].syncVersion, self.sample2.syncVersion)
                XCTAssertEqual(samples[2].startDate, self.sample2.date)
                XCTAssertEqual(samples[2].quantity, self.sample2.quantity)
                XCTAssertEqual(samples[2].isDisplayOnly, self.sample2.isDisplayOnly)
                XCTAssertEqual(samples[2].wasUserEntered, self.sample2.wasUserEntered)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        wait(for: [getGlucoseSamples1Completion], timeout: 10)

        let getGlucoseSamples2Completion = expectation(description: "getGlucoseSamples2")
        glucoseStore.getGlucoseSamples(start: Date(timeIntervalSinceNow: -.minutes(5)), end: Date(timeIntervalSinceNow: -.minutes(3))) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 1)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertEqual(samples[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[0].syncIdentifier, self.sample3.syncIdentifier)
                XCTAssertEqual(samples[0].syncVersion, self.sample3.syncVersion)
                XCTAssertEqual(samples[0].startDate, self.sample3.date)
                XCTAssertEqual(samples[0].quantity, self.sample3.quantity)
                XCTAssertEqual(samples[0].isDisplayOnly, self.sample3.isDisplayOnly)
                XCTAssertEqual(samples[0].wasUserEntered, self.sample3.wasUserEntered)
            }
            getGlucoseSamples2Completion.fulfill()
        }
        wait(for: [getGlucoseSamples2Completion], timeout: 10)

        let purgeGlucoseObjectsCompletion = expectation(description: "purgeGlucoseObjects")
        glucoseStore.purgeGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeGlucoseObjectsCompletion.fulfill()
        }
        wait(for: [purgeGlucoseObjectsCompletion], timeout: 10)

        let getGlucoseSamples3Completion = expectation(description: "getGlucoseSamples3")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            getGlucoseSamples3Completion.fulfill()
        }
        wait(for: [getGlucoseSamples3Completion], timeout: 10)
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
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        wait(for: [addGlucoseSamplesCompletion], timeout: 10)

        XCTAssertNotNil(glucoseStore.latestGlucose)
        XCTAssertEqual(glucoseStore.latestGlucose?.startDate, sample2.date)
        XCTAssertEqual(glucoseStore.latestGlucose?.endDate, sample2.date)
        XCTAssertEqual(glucoseStore.latestGlucose?.quantity, sample2.quantity)
        XCTAssertEqual(glucoseStore.latestGlucose?.provenanceIdentifier, HKSource.default().bundleIdentifier)
        XCTAssertEqual(glucoseStore.latestGlucose?.isDisplayOnly, sample2.isDisplayOnly)
        XCTAssertEqual(glucoseStore.latestGlucose?.wasUserEntered, sample2.wasUserEntered)

        let purgeGlucoseObjectsCompletion = expectation(description: "purgeGlucoseObjects")
        glucoseStore.purgeGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeGlucoseObjectsCompletion.fulfill()
        }
        wait(for: [purgeGlucoseObjectsCompletion], timeout: 10)

        XCTAssertNil(glucoseStore.latestGlucose)
    }

    // MARK: - Modification

    func testAddGlucoseSamples() {
        let addGlucoseSamples1Completion = expectation(description: "addGlucoseSamples1")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertEqual(samples[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[0].syncIdentifier, self.sample1.syncIdentifier)
                XCTAssertEqual(samples[0].syncVersion, self.sample1.syncVersion)
                XCTAssertEqual(samples[0].startDate, self.sample1.date)
                XCTAssertEqual(samples[0].quantity, self.sample1.quantity)
                XCTAssertEqual(samples[0].isDisplayOnly, self.sample1.isDisplayOnly)
                XCTAssertEqual(samples[0].wasUserEntered, self.sample1.wasUserEntered)
                XCTAssertNotNil(samples[1].uuid)
                XCTAssertEqual(samples[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[1].syncIdentifier, self.sample2.syncIdentifier)
                XCTAssertEqual(samples[1].syncVersion, self.sample2.syncVersion)
                XCTAssertEqual(samples[1].startDate, self.sample2.date)
                XCTAssertEqual(samples[1].quantity, self.sample2.quantity)
                XCTAssertEqual(samples[1].isDisplayOnly, self.sample2.isDisplayOnly)
                XCTAssertEqual(samples[1].wasUserEntered, self.sample2.wasUserEntered)
                XCTAssertNotNil(samples[2].uuid)
                XCTAssertEqual(samples[2].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[2].syncIdentifier, self.sample3.syncIdentifier)
                XCTAssertEqual(samples[2].syncVersion, self.sample3.syncVersion)
                XCTAssertEqual(samples[2].startDate, self.sample3.date)
                XCTAssertEqual(samples[2].quantity, self.sample3.quantity)
                XCTAssertEqual(samples[2].isDisplayOnly, self.sample3.isDisplayOnly)
                XCTAssertEqual(samples[2].wasUserEntered, self.sample3.wasUserEntered)
            }
            addGlucoseSamples1Completion.fulfill()
        }
        wait(for: [addGlucoseSamples1Completion], timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertEqual(samples[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[0].syncIdentifier, self.sample1.syncIdentifier)
                XCTAssertEqual(samples[0].syncVersion, self.sample1.syncVersion)
                XCTAssertEqual(samples[0].startDate, self.sample1.date)
                XCTAssertEqual(samples[0].quantity, self.sample1.quantity)
                XCTAssertEqual(samples[0].isDisplayOnly, self.sample1.isDisplayOnly)
                XCTAssertEqual(samples[0].wasUserEntered, self.sample1.wasUserEntered)
                XCTAssertNotNil(samples[1].uuid)
                XCTAssertEqual(samples[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[1].syncIdentifier, self.sample3.syncIdentifier)
                XCTAssertEqual(samples[1].syncVersion, self.sample3.syncVersion)
                XCTAssertEqual(samples[1].startDate, self.sample3.date)
                XCTAssertEqual(samples[1].quantity, self.sample3.quantity)
                XCTAssertEqual(samples[1].isDisplayOnly, self.sample3.isDisplayOnly)
                XCTAssertEqual(samples[1].wasUserEntered, self.sample3.wasUserEntered)
                XCTAssertNotNil(samples[2].uuid)
                XCTAssertEqual(samples[2].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[2].syncIdentifier, self.sample2.syncIdentifier)
                XCTAssertEqual(samples[2].syncVersion, self.sample2.syncVersion)
                XCTAssertEqual(samples[2].startDate, self.sample2.date)
                XCTAssertEqual(samples[2].quantity, self.sample2.quantity)
                XCTAssertEqual(samples[2].isDisplayOnly, self.sample2.isDisplayOnly)
                XCTAssertEqual(samples[2].wasUserEntered, self.sample2.wasUserEntered)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        wait(for: [getGlucoseSamples1Completion], timeout: 10)

        let addGlucoseSamples2Completion = expectation(description: "addGlucoseSamples2")
        glucoseStore.addGlucoseSamples([sample3, sample1, sample2]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            addGlucoseSamples2Completion.fulfill()
        }
        wait(for: [addGlucoseSamples2Completion], timeout: 10)

        let getGlucoseSamples2Completion = expectation(description: "getGlucoseSamples2Completion")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertEqual(samples[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[0].syncIdentifier, self.sample1.syncIdentifier)
                XCTAssertEqual(samples[0].syncVersion, self.sample1.syncVersion)
                XCTAssertEqual(samples[0].startDate, self.sample1.date)
                XCTAssertEqual(samples[0].quantity, self.sample1.quantity)
                XCTAssertEqual(samples[0].isDisplayOnly, self.sample1.isDisplayOnly)
                XCTAssertEqual(samples[0].wasUserEntered, self.sample1.wasUserEntered)
                XCTAssertNotNil(samples[1].uuid)
                XCTAssertEqual(samples[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[1].syncIdentifier, self.sample3.syncIdentifier)
                XCTAssertEqual(samples[1].syncVersion, self.sample3.syncVersion)
                XCTAssertEqual(samples[1].startDate, self.sample3.date)
                XCTAssertEqual(samples[1].quantity, self.sample3.quantity)
                XCTAssertEqual(samples[1].isDisplayOnly, self.sample3.isDisplayOnly)
                XCTAssertEqual(samples[1].wasUserEntered, self.sample3.wasUserEntered)
                XCTAssertNotNil(samples[2].uuid)
                XCTAssertEqual(samples[2].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(samples[2].syncIdentifier, self.sample2.syncIdentifier)
                XCTAssertEqual(samples[2].syncVersion, self.sample2.syncVersion)
                XCTAssertEqual(samples[2].startDate, self.sample2.date)
                XCTAssertEqual(samples[2].quantity, self.sample2.quantity)
                XCTAssertEqual(samples[2].isDisplayOnly, self.sample2.isDisplayOnly)
                XCTAssertEqual(samples[2].wasUserEntered, self.sample2.wasUserEntered)
            }
            getGlucoseSamples2Completion.fulfill()
        }
        wait(for: [getGlucoseSamples2Completion], timeout: 10)
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
        wait(for: [addGlucoseSamplesCompletion], timeout: 10)
    }

    func testAddGlucoseSamplesNotification() {
        delegateCompletion = expectation(description: "delegate")
        let glucoseSamplesDidChangeCompletion = expectation(description: "glucoseSamplesDidChange")
        let observer = NotificationCenter.default.addObserver(forName: GlucoseStore.glucoseSamplesDidChange, object: glucoseStore, queue: nil) { notification in
            let updateSource = notification.userInfo?[HealthKitSampleStore.notificationUpdateSourceKey] as? Int
            XCTAssertEqual(updateSource, UpdateSource.changedInApp.rawValue)
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
        wait(for: [glucoseSamplesDidChangeCompletion, delegateCompletion!, addGlucoseSamplesCompletion], timeout: 10, enforceOrder: true)

        NotificationCenter.default.removeObserver(observer)
        delegateCompletion = nil
    }

    // MARK: - Watch Synchronization

    func testSyncGlucoseObjects() {
        var syncGlucoseObjects: [SyncGlucoseObject] = []

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
        wait(for: [addGlucoseSamplesCompletion], timeout: 10)

        let getSyncGlucoseObjects1Completion = expectation(description: "getSyncGlucoseObjects1")
        glucoseStore.getSyncGlucoseObjects() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let objects):
                XCTAssertEqual(objects.count, 3)
                XCTAssertNotNil(objects[0].uuid)
                XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(objects[0].syncIdentifier, self.sample1.syncIdentifier)
                XCTAssertEqual(objects[0].syncVersion, self.sample1.syncVersion)
                XCTAssertEqual(objects[0].value, self.sample1.quantity.doubleValue(for: .milligramsPerDeciliter))
                XCTAssertEqual(objects[0].unitString, HKUnit.milligramsPerDeciliter.unitString)
                XCTAssertEqual(objects[0].startDate, self.sample1.date)
                XCTAssertEqual(objects[0].isDisplayOnly, self.sample1.isDisplayOnly)
                XCTAssertEqual(objects[0].wasUserEntered, self.sample1.wasUserEntered)
                XCTAssertNotNil(objects[1].uuid)
                XCTAssertEqual(objects[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(objects[1].syncIdentifier, self.sample3.syncIdentifier)
                XCTAssertEqual(objects[1].syncVersion, self.sample3.syncVersion)
                XCTAssertEqual(objects[1].value, self.sample3.quantity.doubleValue(for: .milligramsPerDeciliter))
                XCTAssertEqual(objects[1].unitString, HKUnit.milligramsPerDeciliter.unitString)
                XCTAssertEqual(objects[1].startDate, self.sample3.date)
                XCTAssertEqual(objects[1].isDisplayOnly, self.sample3.isDisplayOnly)
                XCTAssertEqual(objects[1].wasUserEntered, self.sample3.wasUserEntered)
                XCTAssertNotNil(objects[2].uuid)
                XCTAssertEqual(objects[2].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(objects[2].syncIdentifier, self.sample2.syncIdentifier)
                XCTAssertEqual(objects[2].syncVersion, self.sample2.syncVersion)
                XCTAssertEqual(objects[2].value, self.sample2.quantity.doubleValue(for: .milligramsPerDeciliter))
                XCTAssertEqual(objects[2].unitString, HKUnit.milligramsPerDeciliter.unitString)
                XCTAssertEqual(objects[2].startDate, self.sample2.date)
                XCTAssertEqual(objects[2].isDisplayOnly, self.sample2.isDisplayOnly)
                XCTAssertEqual(objects[2].wasUserEntered, self.sample2.wasUserEntered)
                syncGlucoseObjects = objects
            }
            getSyncGlucoseObjects1Completion.fulfill()
        }
        wait(for: [getSyncGlucoseObjects1Completion], timeout: 10)

        let getSyncGlucoseObjects2Completion = expectation(description: "getSyncGlucoseObjects2")
        glucoseStore.getSyncGlucoseObjects(start: Date(timeIntervalSinceNow: -.minutes(5)), end: Date(timeIntervalSinceNow: -.minutes(3))) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let objects):
                XCTAssertEqual(objects.count, 1)
                XCTAssertNotNil(objects[0].uuid)
                XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(objects[0].syncIdentifier, self.sample3.syncIdentifier)
                XCTAssertEqual(objects[0].syncVersion, self.sample3.syncVersion)
                XCTAssertEqual(objects[0].value, self.sample3.quantity.doubleValue(for: .milligramsPerDeciliter))
                XCTAssertEqual(objects[0].unitString, HKUnit.milligramsPerDeciliter.unitString)
                XCTAssertEqual(objects[0].startDate, self.sample3.date)
                XCTAssertEqual(objects[0].isDisplayOnly, self.sample3.isDisplayOnly)
                XCTAssertEqual(objects[0].wasUserEntered, self.sample3.wasUserEntered)
            }
            getSyncGlucoseObjects2Completion.fulfill()
        }
        wait(for: [getSyncGlucoseObjects2Completion], timeout: 10)

        let purgeGlucoseObjectsCompletion = expectation(description: "purgeGlucoseObjects")
        glucoseStore.purgeGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeGlucoseObjectsCompletion.fulfill()
        }
        wait(for: [purgeGlucoseObjectsCompletion], timeout: 10)

        let getSyncGlucoseObjects3Completion = expectation(description: "getSyncGlucoseObjects3")
        glucoseStore.getSyncGlucoseObjects() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            getSyncGlucoseObjects3Completion.fulfill()
        }
        wait(for: [getSyncGlucoseObjects3Completion], timeout: 10)

        let setSyncGlucoseObjectsCompletion = expectation(description: "setSyncGlucoseObjects")
        glucoseStore.setSyncGlucoseObjects(syncGlucoseObjects) { error in
            XCTAssertNil(error)
            setSyncGlucoseObjectsCompletion.fulfill()
        }
        wait(for: [setSyncGlucoseObjectsCompletion], timeout: 10)

        let getSyncGlucoseObjects4Completion = expectation(description: "getSyncGlucoseObjects4")
        glucoseStore.getSyncGlucoseObjects() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let objects):
                XCTAssertEqual(objects.count, 3)
                XCTAssertNotNil(objects[0].uuid)
                XCTAssertEqual(objects[0].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(objects[0].syncIdentifier, self.sample1.syncIdentifier)
                XCTAssertEqual(objects[0].syncVersion, self.sample1.syncVersion)
                XCTAssertEqual(objects[0].value, self.sample1.quantity.doubleValue(for: .milligramsPerDeciliter))
                XCTAssertEqual(objects[0].unitString, HKUnit.milligramsPerDeciliter.unitString)
                XCTAssertEqual(objects[0].startDate, self.sample1.date)
                XCTAssertEqual(objects[0].isDisplayOnly, self.sample1.isDisplayOnly)
                XCTAssertEqual(objects[0].wasUserEntered, self.sample1.wasUserEntered)
                XCTAssertNotNil(objects[1].uuid)
                XCTAssertEqual(objects[1].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(objects[1].syncIdentifier, self.sample3.syncIdentifier)
                XCTAssertEqual(objects[1].syncVersion, self.sample3.syncVersion)
                XCTAssertEqual(objects[1].value, self.sample3.quantity.doubleValue(for: .milligramsPerDeciliter))
                XCTAssertEqual(objects[1].unitString, HKUnit.milligramsPerDeciliter.unitString)
                XCTAssertEqual(objects[1].startDate, self.sample3.date)
                XCTAssertEqual(objects[1].isDisplayOnly, self.sample3.isDisplayOnly)
                XCTAssertEqual(objects[1].wasUserEntered, self.sample3.wasUserEntered)
                XCTAssertNotNil(objects[2].uuid)
                XCTAssertEqual(objects[2].provenanceIdentifier, HKSource.default().bundleIdentifier)
                XCTAssertEqual(objects[2].syncIdentifier, self.sample2.syncIdentifier)
                XCTAssertEqual(objects[2].syncVersion, self.sample2.syncVersion)
                XCTAssertEqual(objects[2].value, self.sample2.quantity.doubleValue(for: .milligramsPerDeciliter))
                XCTAssertEqual(objects[2].unitString, HKUnit.milligramsPerDeciliter.unitString)
                XCTAssertEqual(objects[2].startDate, self.sample2.date)
                XCTAssertEqual(objects[2].isDisplayOnly, self.sample2.isDisplayOnly)
                XCTAssertEqual(objects[2].wasUserEntered, self.sample2.wasUserEntered)
                syncGlucoseObjects = objects
            }
            getSyncGlucoseObjects4Completion.fulfill()
        }
        wait(for: [getSyncGlucoseObjects4Completion], timeout: 10)
    }

    // MARK: - Cache Management

    func testEarliestCacheDate() {
        XCTAssertEqual(glucoseStore.earliestCacheDate.timeIntervalSinceNow, -.hours(1), accuracy: 1)
    }

    func testPurgeAllGlucoseSamples() {
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
        wait(for: [addGlucoseSamplesCompletion], timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        wait(for: [getGlucoseSamples1Completion], timeout: 10)

        let purgeAllGlucoseSamplesCompletion = expectation(description: "purgeAllGlucoseSamples")
        glucoseStore.purgeAllGlucoseSamples(healthKitPredicate: HKQuery.predicateForObjects(from: HKSource.default())) { error in
            XCTAssertNil(error)
            purgeAllGlucoseSamplesCompletion.fulfill()

        }
        wait(for: [purgeAllGlucoseSamplesCompletion], timeout: 10)

        let getGlucoseSample22Completion = expectation(description: "getGlucoseSample22")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            getGlucoseSample22Completion.fulfill()
        }
        wait(for: [getGlucoseSample22Completion], timeout: 10)
    }

    func testPurgeExpiredGlucoseObjects() {
        let expiredSample = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.hours(2)),
                                             quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 198.7),
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
        wait(for: [addGlucoseSamplesCompletion], timeout: 10)

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
        wait(for: [getGlucoseSamplesCompletion], timeout: 10)
    }

    func testPurgeGlucoseObjects() {
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
        wait(for: [addGlucoseSamplesCompletion], timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        wait(for: [getGlucoseSamples1Completion], timeout: 10)

        let purgeGlucoseObjects1Completion = expectation(description: "purgeGlucoseObjects1")
        glucoseStore.purgeGlucoseObjects(before: Date(timeIntervalSinceNow: -.minutes(5))) { error in
            XCTAssertNil(error)
            purgeGlucoseObjects1Completion.fulfill()

        }
        wait(for: [purgeGlucoseObjects1Completion], timeout: 10)

        let getGlucoseSamples2Completion = expectation(description: "getGlucoseSamples2")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 2)
            }
            getGlucoseSamples2Completion.fulfill()
        }
        wait(for: [getGlucoseSamples2Completion], timeout: 10)

        let purgeGlucoseObjects2Completion = expectation(description: "purgeGlucoseObjects2")
        glucoseStore.purgeGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeGlucoseObjects2Completion.fulfill()

        }
        wait(for: [purgeGlucoseObjects2Completion], timeout: 10)

        let getGlucoseSamples3Completion = expectation(description: "getGlucoseSamples3")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            getGlucoseSamples3Completion.fulfill()
        }
        wait(for: [getGlucoseSamples3Completion], timeout: 10)
    }

    func testPurgeGlucoseObjectsNotification() {
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
        wait(for: [addGlucoseSamplesCompletion], timeout: 10)

        delegateCompletion = expectation(description: "delegate")
        let glucoseSamplesDidChangeCompletion = expectation(description: "glucoseSamplesDidChange")
        let observer = NotificationCenter.default.addObserver(forName: GlucoseStore.glucoseSamplesDidChange, object: glucoseStore, queue: nil) { notification in
            let updateSource = notification.userInfo?[HealthKitSampleStore.notificationUpdateSourceKey] as? Int
            XCTAssertEqual(updateSource, UpdateSource.changedInApp.rawValue)
            glucoseSamplesDidChangeCompletion.fulfill()
        }

        let purgeGlucoseObjectsCompletion = expectation(description: "purgeGlucoseObjects")
        glucoseStore.purgeGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeGlucoseObjectsCompletion.fulfill()

        }
        wait(for: [glucoseSamplesDidChangeCompletion, delegateCompletion!, purgeGlucoseObjectsCompletion], timeout: 10, enforceOrder: true)

        NotificationCenter.default.removeObserver(observer)
        delegateCompletion = nil
    }

    private let dateFormatter = ISO8601DateFormatter()
}

fileprivate extension NewGlucoseSample {
    static var test: NewGlucoseSample {
        return NewGlucoseSample(date: Date(),
                                quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.45),
                                isDisplayOnly: false,
                                wasUserEntered: false,
                                syncIdentifier: UUID().uuidString)
    }
}
