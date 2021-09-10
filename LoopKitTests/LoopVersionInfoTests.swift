//
//  LoopVersionInfoTests.swift
//  LoopKitTests
//
//  Created by Rick Pasetto on 9/10/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class LoopVersionInfoTests: XCTestCase {

    let info = LoopVersionInfo(minimumSupported: "1.2.0", criticalUpdateNeeded: ["1.1.0", "0.3.1"])

    func testNeedsCriticalUpdate() {
        XCTAssertFalse(info.needsCriticalUpdate(version: "1.2.0"))
        XCTAssertTrue(info.needsCriticalUpdate(version: "1.1.0"))
    }
    func testNeedsSupportedUpdate() {
        XCTAssertFalse(info.needsSupportedUpdate(version: "1.2.0"))
        XCTAssertFalse(info.needsSupportedUpdate(version: "1.2.1"))
        XCTAssertFalse(info.needsSupportedUpdate(version: "2.1.0"))
        XCTAssertTrue(info.needsSupportedUpdate(version: "0.1.0"))
        XCTAssertTrue(info.needsSupportedUpdate(version: "0.3.0"))
        XCTAssertTrue(info.needsSupportedUpdate(version: "0.3.1"))
        XCTAssertTrue(info.needsSupportedUpdate(version: "1.1.0"))
        XCTAssertTrue(info.needsSupportedUpdate(version: "1.1.99"))
    }
    func testGetVersionUpdateNeeded() {
        XCTAssertEqual(.noneNeeded, info.getVersionUpdateNeeded(currentVersion: "1.2.0"))
        XCTAssertEqual(.noneNeeded, info.getVersionUpdateNeeded(currentVersion: "1.2.1"))
        XCTAssertEqual(.noneNeeded, info.getVersionUpdateNeeded(currentVersion: "2.1.0"))
        XCTAssertEqual(.supportedNeeded, info.getVersionUpdateNeeded(currentVersion: "0.1.0"))
        XCTAssertEqual(.supportedNeeded, info.getVersionUpdateNeeded(currentVersion: "0.3.0"))
        XCTAssertEqual(.criticalNeeded, info.getVersionUpdateNeeded(currentVersion: "0.3.1"))
        XCTAssertEqual(.criticalNeeded, info.getVersionUpdateNeeded(currentVersion: "1.1.0"))
        XCTAssertEqual(.supportedNeeded, info.getVersionUpdateNeeded(currentVersion: "1.1.99"))
    }
}

class SemanticVersionTests: XCTestCase {
    
    func testInvalid() {
        XCTAssertNil(SemanticVersion("abc123"))
        XCTAssertNil(SemanticVersion("foopyNoopy"))
        XCTAssertNil(SemanticVersion("1.2.3.4"))
        XCTAssertNil(SemanticVersion("-1.2.3.4"))
        XCTAssertNotNil(SemanticVersion("1.2.3"))
        XCTAssertNotNil(SemanticVersion("1.0.3"))
        XCTAssertNotNil(SemanticVersion("00.00.00"))
    }
    
    func testComparable() {
        XCTAssertEqual(SemanticVersion("1.2.3"), SemanticVersion("1.2.3"))
        XCTAssertEqual(SemanticVersion("01.2.3"), SemanticVersion("1.2.3"))
        XCTAssertEqual(SemanticVersion("00.00.00"), SemanticVersion("0.0.0"))
        XCTAssertGreaterThan(SemanticVersion("1.2.3")!, SemanticVersion("1.2.2")!)
        XCTAssertLessThan(SemanticVersion("1.2.1")!, SemanticVersion("1.2.2")!)
        XCTAssertGreaterThan(SemanticVersion("1.3.2")!, SemanticVersion("1.2.2")!)
        XCTAssertLessThan(SemanticVersion("1.1.1")!, SemanticVersion("1.2.1")!)
        XCTAssertGreaterThan(SemanticVersion("2.2.3")!, SemanticVersion("1.2.3")!)
        XCTAssertLessThan(SemanticVersion("1.2.3")!, SemanticVersion("2.2.3")!)
    }
}
