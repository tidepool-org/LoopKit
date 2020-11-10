//
//  GuardrailTests.swift
//  GuardrailTests
//
//  Created by Michael Pangburn on 7/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class GuardrailTests: XCTestCase {
    let correctionRangeSchedule120 = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: DoubleRange(120...130))])
    let preMealTargetRange120 = DoubleRange(120...130)
    let workoutTargetRange120 = DoubleRange(120...130)
    let correctionRangeSchedule80 = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: DoubleRange(80...100))])
    let preMealTargetRange85 = DoubleRange(85...100)
    let workoutTargetRange90 = DoubleRange(90...100)

    func testMaxSuspensionThresholdValue() {
        let correctionRangeInputs = [ nil, correctionRangeSchedule120, correctionRangeSchedule80 ]
        let preMealInputs = [ nil, preMealTargetRange120, preMealTargetRange85 ]
        let workoutInputs = [ nil, workoutTargetRange120, workoutTargetRange90 ]
        let expected: [Double] = [ 110, 110, 90,
                                   110, 110, 90,
                                   85, 85, 85,
                                   110, 110, 90,
                                   110, 110, 90,
                                   85, 85, 85,
                                   80, 80, 80,
                                   80, 80, 80,
                                   80, 80, 80 ]
        var index = 0
        for correctionRange in correctionRangeInputs {
            for preMeal in preMealInputs {
                for workout in workoutInputs {
                    let maxSuspendThresholdValue = Guardrail.maxSuspendThresholdValue(correctionRangeSchedule: correctionRange, preMealTargetRange: preMeal, workoutTargetRange: workout, unit: .milligramsPerDeciliter).doubleValue(for: .milligramsPerDeciliter)
                    XCTAssertEqual(expected[index], maxSuspendThresholdValue, "Index \(index) failed")
                    index += 1
                }
            }
        }
    }
    
    func testMinCorrectionRangeValue() {
        let suspendThresholdInputs: [Double?] = [ nil, 80, 88 ]
        let expected: [Double] = [ 87, 87, 88 ]
        for (index, suspendThreshold) in suspendThresholdInputs.enumerated() {
            XCTAssertEqual(expected[index], Guardrail.minCorrectionRangeValue(suspendThreshold: suspendThreshold.map { GlucoseThreshold(unit: .milligramsPerDeciliter, value: $0) }, unit: .milligramsPerDeciliter).doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
        }
    }
    
    func testWorkoutCorrectionRange() {
        let correctionRangeInputs = [ 70...80, 70...85, 70...90 ]
        let suspendThresholdInputs: [Double?] = [ nil, 81, 91 ]
        let expectedLow: [Double] = [ 85, 85, 91,
                                      85, 85, 91,
                                      90, 90, 91 ]
        let expectedMin: [Double] = [ 85, 85, 91, 85, 85, 91, 85, 85, 91 ]

        var index = 0
        for correctionRange in correctionRangeInputs {
            for suspendThreshold in suspendThresholdInputs {
                let guardrail = Guardrail.correctionRangeOverride(for: .workout, correctionRangeScheduleRange: correctionRange.range(withUnit: .milligramsPerDeciliter), suspendThreshold: suspendThreshold.map { GlucoseThreshold(unit: .milligramsPerDeciliter, value: $0) }, unit: .milligramsPerDeciliter)
                XCTAssertEqual(expectedLow[index], guardrail.recommendedBounds.lowerBound.doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
                XCTAssertEqual(expectedMin[index], guardrail.absoluteBounds.lowerBound.doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
                index += 1
            }
        }
    }

    func testPreMealCorrectionRange() {
        let correctionRangeInputs = [ 60...80, 100...110, 150...180 ]
        let suspendThresholdInputs: [Double?] = [ nil, 90 ]
        let expectedRecommendedHigh: [Double] = [ 67, 90,
                                                  100, 100,
                                                  130, 130 ]
        let expectedMin: [Double] = [ 67, 90, 67, 90, 67, 90 ]

        var index = 0
        for correctionRange in correctionRangeInputs {
            for suspendThreshold in suspendThresholdInputs {
                let guardrail = Guardrail.correctionRangeOverride(for: .preMeal, correctionRangeScheduleRange: correctionRange.range(withUnit: .milligramsPerDeciliter), suspendThreshold: suspendThreshold.map { GlucoseThreshold(unit: .milligramsPerDeciliter, value: $0) }, unit: .milligramsPerDeciliter)
                XCTAssertEqual(expectedRecommendedHigh[index], guardrail.recommendedBounds.upperBound.doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
                XCTAssertEqual(expectedMin[index], guardrail.absoluteBounds.lowerBound.doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
                XCTAssertEqual(guardrail.absoluteBounds.lowerBound.doubleValue(for: .milligramsPerDeciliter),
                               guardrail.recommendedBounds.lowerBound.doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
                index += 1
            }
        }
    }
    
    func testCarbRatioGuardrail() {
        XCTAssertEqual(Guardrail.carbRatio.absoluteBounds.range(withUnit: .gramsPerUnit), 2.0...150.0)
        XCTAssertEqual(Guardrail.carbRatio.recommendedBounds.range(withUnit: .gramsPerUnit), 4...28)
    }

    func testBasalRateGuardrail() {
        let supportedBasalRates = (2...600).map { Double($0) / 20 }
        let guardrail = Guardrail.basalRate(supportedBasalRates: supportedBasalRates)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.1...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 0.1...30.0)
    }

    func testBasalRateGuardrailClampedLow() {
        let supportedBasalRates = [0.01, 30.0]
        let guardrail = Guardrail.basalRate(supportedBasalRates: supportedBasalRates)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.05...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 0.05...30.0)
    }

    func testBasalRateGuardrailClampedHigh() {
        let supportedBasalRates = (2...800).map { Double($0) / 20 }
        let guardrail = Guardrail.basalRate(supportedBasalRates: supportedBasalRates)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.1...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 0.1...30.0)
    }

    func testBasalRateGuardrailZeroDropsFirst() {
        let supportedBasalRates = (0...600).map { Double($0) / 20 }
        let guardrail = Guardrail.basalRate(supportedBasalRates: supportedBasalRates)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.1...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 0.1...30.0)
    }

    func testMaxBasalRateGuardrail() {
        let supportedBasalRates = (1...600).map { Double($0) / 20 }
        let scheduledBasalRange = 0.05...0.78125
        let lowestCarbRatio = 10.0
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.78125...7.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 1.6...5.0)
    }
    
    func testMaxBasalRateGuardrailNoCarbRatio() {
        let supportedBasalRates = (1...600).map { Double($0) / 20 }
        let scheduledBasalRange = 0.05...0.78125
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: nil)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.78125...35.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 1.6...5.0)
    }
    
    func testMaxBasalRateGuardrailFewSupportedBasalRates() {
        let supportedBasalRates = [0.05, 1.0]
        let scheduledBasalRange = 0.05...0.78125
        let lowestCarbRatio = 10.0
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.78125...7.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 1.0...1.0)
    }
    
    func testMaxBasalRateGuardrailHighestScheduledBasalZero() {
        let supportedBasalRates = [0.0, 1.0]
        let scheduledBasalRange = 0.0...0.0
        let lowestCarbRatio = 10.0
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.0...7.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 0.0...0.0)
    }
    
    func testMaxBasalRateGuardrailNoScheduledBasalRates() {
        let supportedBasalRates = [0.0, 1.0]
        let lowestCarbRatio = 10.0
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: nil, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.0...7.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 0.0...7.0)
    }
}

fileprivate extension ClosedRange where Bound == HKQuantity {
    func range(withUnit unit: HKUnit) -> ClosedRange<Double> {
        lowerBound.doubleValue(for: unit)...upperBound.doubleValue(for: unit)
    }
}

fileprivate extension ClosedRange where Bound == Int {
    func range(withUnit unit: HKUnit) -> ClosedRange<HKQuantity> {
        HKQuantity(unit: unit, doubleValue: Double(lowerBound))...HKQuantity(unit: unit, doubleValue: Double(upperBound))
    }
}
