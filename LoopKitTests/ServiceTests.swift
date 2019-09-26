//
//  ServiceTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 9/15/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest

@testable import LoopKit


class ServiceTests: XCTestCase {

    fileprivate var testService: TestService!
    
    fileprivate var testServiceDelegate: TestServiceDelegate!

    override func setUp() {
        testService = TestService()
        testServiceDelegate = TestServiceDelegate()
        testService.serviceDelegate = testServiceDelegate
    }

    override func tearDown() {
        testServiceDelegate = nil
        testService = nil
    }

    func testHasConfiguration() {
        XCTAssertTrue(testService.hasConfiguration)
    }

    func testVerifyConfiguration() {
        var error: Error? = TestError()
        testService.verifyConfiguration { error = $0 }
        XCTAssertNil(error)
    }

    func testNotifyCreated() {
        var notified: Bool = false
        let semaphore = DispatchSemaphore(value: 0)
        testService.notifyCreated {
            dispatchPrecondition(condition: .onQueue(self.testService.delegateQueue))
            notified = true
            semaphore.signal()
        }
        XCTAssertEqual(semaphore.wait(timeout: .now() + .seconds(3)), .success)
        XCTAssertTrue(notified)
        XCTAssertFalse(testServiceDelegate.updated)
        XCTAssertFalse(testServiceDelegate.deleted)
    }

    func testNotifyDelegateOfCreation() {
        var notified: Bool = false
        let semaphore = DispatchSemaphore(value: 0)
        testService.notifyDelegateOfCreation {
            dispatchPrecondition(condition: .onQueue(self.testService.delegateQueue))
            notified = true
            semaphore.signal()
        }
        XCTAssertEqual(semaphore.wait(timeout: .now() + .seconds(3)), .success)
        XCTAssertTrue(notified)
        XCTAssertFalse(testServiceDelegate.updated)
        XCTAssertFalse(testServiceDelegate.deleted)
    }

    func testNotifyUpdated() {
        var notified: Bool = false
        let semaphore = DispatchSemaphore(value: 0)
        testService.notifyUpdated {
            dispatchPrecondition(condition: .onQueue(self.testService.delegateQueue))
            notified = true
            semaphore.signal()
        }
        XCTAssertEqual(semaphore.wait(timeout: .now() + .seconds(3)), .success)
        XCTAssertTrue(notified)
        XCTAssertTrue(testServiceDelegate.updated)
        XCTAssertFalse(testServiceDelegate.deleted)
    }

    func testNotifyDelegateOfUpdation() {
        var notified: Bool = false
        let semaphore = DispatchSemaphore(value: 0)
        testService.notifyDelegateOfUpdation {
            dispatchPrecondition(condition: .onQueue(self.testService.delegateQueue))
            notified = true
            semaphore.signal()
        }
        XCTAssertEqual(semaphore.wait(timeout: .now() + .seconds(3)), .success)
        XCTAssertTrue(notified)
        XCTAssertTrue(testServiceDelegate.updated)
        XCTAssertFalse(testServiceDelegate.deleted)
    }

    func testNotifyDeleted() {
        var notified: Bool = false
        let semaphore = DispatchSemaphore(value: 0)
        testService.notifyDeleted {
            dispatchPrecondition(condition: .onQueue(self.testService.delegateQueue))
            notified = true
            semaphore.signal()
        }
        XCTAssertEqual(semaphore.wait(timeout: .now() + .seconds(3)), .success)
        XCTAssertTrue(notified)
        XCTAssertFalse(testServiceDelegate.updated)
        XCTAssertTrue(testServiceDelegate.deleted)
    }

    func testNotifyDelegateOfDeletion() {
        var notified: Bool = false
        let semaphore = DispatchSemaphore(value: 0)
        testService.notifyDelegateOfDeletion {
            dispatchPrecondition(condition: .onQueue(self.testService.delegateQueue))
            notified = true
            semaphore.signal()
        }
        XCTAssertEqual(semaphore.wait(timeout: .now() + .seconds(3)), .success)
        XCTAssertTrue(notified)
        XCTAssertFalse(testServiceDelegate.updated)
        XCTAssertTrue(testServiceDelegate.deleted)
    }

}


fileprivate class TestError: Error {}


fileprivate class TestService: Service {

    static var managerIdentifier: String { return "" }

    static var localizedTitle: String { return "" }

    var delegateQueue: DispatchQueue! = DispatchQueue(label: "com.loopkit.ServiceTests", qos: .utility)

    var serviceDelegate: ServiceDelegate?

    init() {}

    required init?(rawState: RawStateValue) { return nil }

    var rawState: RawStateValue { return [:] }

    var debugDescription: String { return "TestService" }

}


fileprivate class TestServiceDelegate: ServiceDelegate {

    var updated: Bool = false

    var deleted: Bool = false

    func serviceUpdated(_ service: Service) {
        updated = true
    }

    func serviceDeleted(_ service: Service) {
        deleted = true
    }

}
