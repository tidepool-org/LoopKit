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

    override func setUp() {
        testService = TestService()
    }

    override func tearDown() {
        testService = nil
    }

    func testServiceIdentifier() {
        XCTAssertEqual(testService.serviceIdentifier, "TestService")
    }

    func testLocalizedTitle() {
        XCTAssertEqual(testService.localizedTitle, "Test Service")
    }

    func testHasConfiguration() {
        XCTAssertTrue(testService.hasConfiguration)
    }

    func testVerifyConfiguration() {
        var error: Error? = TestError()
        testService.verifyConfiguration { error = $0 }
        XCTAssertNil(error)
    }

    func testCompleteCreate() {
        testService.completeCreate()
    }

    func testCompleteUpdate() {
        testService.completeUpdate()
    }

    func testCompleteDelete() {
        testService.completeDelete()
    }

}

fileprivate class TestError: Error {}

fileprivate class TestService: Service {

    static var serviceIdentifier: String { return "TestService" }

    static var localizedTitle: String { return "Test Service" }

    init() {}

    required init?(rawState: RawStateValue) { return nil }

    var rawState: RawStateValue { return [:] }

}
