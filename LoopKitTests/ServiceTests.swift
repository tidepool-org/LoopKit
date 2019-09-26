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

    static var managerIdentifier: String { return "" }

    static var localizedTitle: String { return "" }

    var delegateQueue: DispatchQueue! = DispatchQueue(label: "com.loopkit.ServiceTests", qos: .utility)

    var serviceDelegate: ServiceDelegate?

    init() {}

    required init?(rawState: RawStateValue) { return nil }

    var rawState: RawStateValue { return [:] }

    var debugDescription: String { return "TestService" }

}
