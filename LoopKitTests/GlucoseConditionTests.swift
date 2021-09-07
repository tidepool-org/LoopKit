//
//  GlucoseConditionTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 9/7/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class GlucoseConditionTests: XCTestCase {
    func testTitleThresholdInitializerWithInvalidTitle() {
        XCTAssertNil(GlucoseCondition(title: "invalid"))
    }

    func testTitleThresholdInitializerWithThreshold() {
        let condition = GlucoseCondition(title: "belowRange", threshold: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.45))
        XCTAssertEqual(condition, .belowRange(threshold: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.45)))
    }

    func testTitleThresholdInitializerWithoutThreshold() {
        let condition = GlucoseCondition(title: "aboveRange")
        XCTAssertEqual(condition, .aboveRange())
    }

    func testRawValueInitializerWithMissingTitle() {
        let rawValue: GlucoseCondition.RawValue = [:]
        XCTAssertNil(GlucoseCondition(rawValue: rawValue))
    }

    func testRawValueInitializerWithInvalidTitle() {
        let rawValue: GlucoseCondition.RawValue = [
            "title": "invalid"
        ]
        XCTAssertNil(GlucoseCondition(rawValue: rawValue))
    }

    func testRawValueInitializerWithThreshold() {
        let rawValue: GlucoseCondition.RawValue = [
            "title": "aboveRange",
            "thresholdUnit": "mg/dL",
            "thresholdValue": 123.45
        ]
        XCTAssertEqual(GlucoseCondition(rawValue: rawValue), .aboveRange(threshold: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.45)))
    }

    func testRawValueInitializerWithoutThreshold() {
        let rawValue: GlucoseCondition.RawValue = [
            "title": "belowRange"
        ]
        XCTAssertEqual(GlucoseCondition(rawValue: rawValue), .belowRange())
    }

    func testRawValueInitializerWithoutThresholdUnit() {
        let rawValue: GlucoseCondition.RawValue = [
            "title": "aboveRange",
            "thresholdValue": 123.45
        ]
        XCTAssertEqual(GlucoseCondition(rawValue: rawValue), .aboveRange())
    }

    func testRawValueInitializerWithoutThresholdValue() {
        let rawValue: GlucoseCondition.RawValue = [
            "title": "belowRange",
            "thresholdUnit": "mg/dL"
        ]
        XCTAssertEqual(GlucoseCondition(rawValue: rawValue), .belowRange())
    }

    func testRawValueWithThreshold() {
        let condition = GlucoseCondition.belowRange(threshold: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.45))
        let rawValue = condition.rawValue
        XCTAssertEqual(rawValue["title"] as? String, "belowRange")
        XCTAssertEqual(rawValue["thresholdUnit"] as? String, HKUnit.milligramsPerDeciliter.unitString)
        XCTAssertEqual(rawValue["thresholdValue"] as? Double, 123.45)
    }

    func testRawValueWithoutThreshold() {
        let condition = GlucoseCondition.aboveRange()
        let rawValue = condition.rawValue
        XCTAssertEqual(rawValue["title"] as? String, "aboveRange")
        XCTAssertNil(rawValue["thresholdUnit"])
        XCTAssertNil(rawValue["thresholdValue"])
    }

    func testTitleBelowRange() {
        let condition = GlucoseCondition.belowRange()
        XCTAssertEqual(condition.title, "belowRange")
    }

    func testTitleAboveRange() {
        let condition = GlucoseCondition.aboveRange()
        XCTAssertEqual(condition.title, "aboveRange")
    }

    func testThresholdNotNil() {
        let threshold = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.45)
        let condition = GlucoseCondition.belowRange(threshold: threshold)
        XCTAssertEqual(condition.threshold, threshold)
    }

    func testThresholdNil() {
        let condition = GlucoseCondition.aboveRange()
        XCTAssertNil(condition.threshold)
    }
}
