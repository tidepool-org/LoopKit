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
    let preMealTargetRange120 = DoubleRange(120...130).quantityRange(for: .milligramsPerDeciliter)
    let workoutTargetRange120 = DoubleRange(120...130).quantityRange(for: .milligramsPerDeciliter)
    let correctionRangeSchedule80 = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: DoubleRange(80...100))])
    let preMealTargetRange85 = DoubleRange(85...100).quantityRange(for: .milligramsPerDeciliter)
    let workoutTargetRange90 = DoubleRange(90...100).quantityRange(for: .milligramsPerDeciliter)

    func testSuspendThresholdUnits() {
        XCTAssertTrue(Guardrail.suspendThreshold.absoluteBounds.contains(HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 67)))
        XCTAssertTrue(Guardrail.suspendThreshold.absoluteBounds.contains(HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 110)))
        XCTAssertTrue(Guardrail.suspendThreshold.absoluteBounds.contains(HKQuantity(unit: .millimolesPerLiter, doubleValue: 6.1)))
        XCTAssertTrue(Guardrail.suspendThreshold.recommendedBounds.contains(HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 74)))
        XCTAssertTrue(Guardrail.suspendThreshold.recommendedBounds.contains(HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)))
        XCTAssertTrue(Guardrail.suspendThreshold.absoluteBounds.contains(HKQuantity(unit: .millimolesPerLiter, doubleValue: 4.44)))
    }

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
                    let maxSuspendThresholdValue = Guardrail.maxSuspendThresholdValue(correctionRangeSchedule: correctionRange, preMealTargetRange: preMeal, workoutTargetRange: workout).doubleValue(for: .milligramsPerDeciliter)
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
            XCTAssertEqual(expected[index], Guardrail.minCorrectionRangeValue(suspendThreshold: suspendThreshold.map { GlucoseThreshold(unit: .milligramsPerDeciliter, value: $0) }).doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
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
                let guardrail = Guardrail.correctionRangeOverride(for: .workout, correctionRangeScheduleRange: correctionRange.range(withUnit: .milligramsPerDeciliter), suspendThreshold: suspendThreshold.map { GlucoseThreshold(unit: .milligramsPerDeciliter, value: $0) })
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
                let guardrail = Guardrail.correctionRangeOverride(for: .preMeal, correctionRangeScheduleRange: correctionRange.range(withUnit: .milligramsPerDeciliter), suspendThreshold: suspendThreshold.map { GlucoseThreshold(unit: .milligramsPerDeciliter, value: $0) })
                XCTAssertEqual(expectedRecommendedHigh[index], guardrail.recommendedBounds.upperBound.doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
                XCTAssertEqual(expectedMin[index], guardrail.absoluteBounds.lowerBound.doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
                XCTAssertEqual(guardrail.absoluteBounds.lowerBound.doubleValue(for: .milligramsPerDeciliter),
                               guardrail.recommendedBounds.lowerBound.doubleValue(for: .milligramsPerDeciliter), "Index \(index) failed")
                index += 1
            }
        }
    }
    
    func testCarbRatioGuardrail() {
        XCTAssertEqual(2.0...150.0, Guardrail.carbRatio.absoluteBounds.range(withUnit: .gramsPerUnit))
        XCTAssertEqual(4...28, Guardrail.carbRatio.recommendedBounds.range(withUnit: .gramsPerUnit))
    }

    func testBasalRateGuardrail() {
        let supportedBasalRates = (2...600).map { Double($0) / 20 }
        let guardrail = Guardrail.basalRate(supportedBasalRates: supportedBasalRates)
        XCTAssertEqual(0.1...30.0, guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour))
        XCTAssertEqual(0.1...30.0, guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour))
    }

    func testBasalRateGuardrailClampedLow() {
        let supportedBasalRates = [0.01, 1.0, 30.0]
        let guardrail = Guardrail.basalRate(supportedBasalRates: supportedBasalRates)
        XCTAssertEqual(1.0...30.0, guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour))
        XCTAssertEqual(1.0...30.0, guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour))
    }

    func testBasalRateGuardrailClampedHigh() {
        let supportedBasalRates = (2...800).map { Double($0) / 20 }
        let guardrail = Guardrail.basalRate(supportedBasalRates: supportedBasalRates)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.1...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 0.1...30.0)
    }

    func testBasalRateGuardrailZeroDropsFirst() {
        let supportedBasalRates = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
        let guardrail = Guardrail.basalRate(supportedBasalRates: supportedBasalRates)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour),  1.0...5.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 1.0...5.0)
    }

    func testMaxBasalRateGuardrail() {
        let supportedBasalRates = (1...600).map { Double($0) / 20 }
        let scheduledBasalRange = 0.05...0.78125
        let lowestCarbRatio = 10.0
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.78125...7.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 1.6...5.0)
    }
    
    func testMaxBasalRateGuardrailHigherCarbRatioClampsRecommendedBounds() {
        let supportedBasalRates = (1...600).map { Double($0) / 20 }
        let scheduledBasalRange = 0.05...0.78125
        let lowestCarbRatio = 15.0
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.78125...4.65)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 1.6...4.65)
    }
    
    func testMaxBasalRateGuardrailNoCarbRatio() {
        let supportedBasalRates = (1...600).map { Double($0) / 20 }
        let scheduledBasalRange = 0.05...0.78125
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: nil)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.78125...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 1.6...5.0)
    }
    
    func testMaxBasalRateGuardrailFewSupportedBasalRates() {
        let supportedBasalRates = [0.05, 1.0]
        let scheduledBasalRange = 0.05...0.78125
        let lowestCarbRatio = 10.0
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.78125...1.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 1.0...1.0)
    }
    
    func testMaxBasalRateGuardrailHighestScheduledBasalZero() {
        let supportedBasalRates = [0.0, 1.0]
        let scheduledBasalRange = 0.0...0.0
        let lowestCarbRatio = 10.0
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.0...1.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 0.0...0.0)
    }
    
    func testMaxBasalRateGuardrailNoScheduledBasalRates() {
        let supportedBasalRates = [0, 0.05, 1.0]
        let lowestCarbRatio = 10.0
        let guardrail = Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: nil, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnitsPerHour), 0.05...1.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnitsPerHour), 0.05...1.0)
    }
    
    func testSelectableBasalRatesGuardrail() {
        let supportedBasalRates = [0, 0.05, 1.0]
        let scheduledBasalRange = 0.05...0.78125
        let lowestCarbRatio = 10.0
        let selectableBasalRates = Guardrail.selectableMaxBasalRates(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual([1.0], selectableBasalRates)
    }
    
    func testSelectableBasalRatesGuardrailNoScheduledBasalRates() {
        let supportedBasalRates = [0, 0.05, 1.0]
        let lowestCarbRatio = 10.0
        let selectableBasalRates = Guardrail.selectableMaxBasalRates(supportedBasalRates: supportedBasalRates, scheduledBasalRange: nil, lowestCarbRatio: lowestCarbRatio)
        XCTAssertEqual([0.05, 1.0], selectableBasalRates)
    }
    
    func testMaxBolusGuardrailInsideLimits() {
        let supportedBolusVolumes = [0.05, 1.0, 2.0]
        let guardrail = Guardrail.maximumBolus(supportedBolusVolumes: supportedBolusVolumes)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnit()), 0.05...2.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnit()), 1.0...2.0)
    }
    
    func testMaxBolusGuardrailClamped() {
        let supportedBolusVolumes = [0.05, 1.0, 2.0, 20.0.nextDown, 20.0, 25.0, 30.0, 30.0.nextUp]
        let guardrail = Guardrail.maximumBolus(supportedBolusVolumes: supportedBolusVolumes)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnit()), 0.05...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnit()), 1.0...20.0.nextDown)
    }
    
    func testMaxBolusGuardrailDropsZeroVolume() {
        let supportedBolusVolumes = [0.0, 0.05, 1.0, 2.0, 20.0.nextDown, 20.0, 25.0, 30.0, 30.0.nextUp]
        let guardrail = Guardrail.maximumBolus(supportedBolusVolumes: supportedBolusVolumes)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnit()), 0.05...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnit()), 1.0...20.0.nextDown)
    }
    
    func testMaxBolusGuardrailDropsAllZeroVolumes() {
        let supportedBolusVolumes = [0.0, 0.0, 0.05, 1.0, 2.0, 20.0.nextDown, 20.0, 25.0, 30.0, 30.0.nextUp]
        let guardrail = Guardrail.maximumBolus(supportedBolusVolumes: supportedBolusVolumes)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnit()), 0.05...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnit()), 1.0...20.0.nextDown)
    }
    
    func testMaxBolusGuardrailDropsNegatives() {
        let supportedBolusVolumes = [-2.0, -1.0, 0.05, 1.0, 2.0, 20.0.nextDown, 20.0, 25.0, 30.0, 30.0.nextUp]
        let guardrail = Guardrail.maximumBolus(supportedBolusVolumes: supportedBolusVolumes)
        XCTAssertEqual(guardrail.absoluteBounds.range(withUnit: .internationalUnit()), 0.05...30.0)
        XCTAssertEqual(guardrail.recommendedBounds.range(withUnit: .internationalUnit()), 1.0...20.0.nextDown)
    }
    
    func testSelectableBolusVolumes() {
        let supportedBolusVolumes = [0.0, 0.05, 1.0, 2.0, 30.nextUp]
        let selectableBolusVolumes = Guardrail.selectableBolusVolumes(supportedBolusVolumes: supportedBolusVolumes)
        XCTAssertEqual([0.05, 1.0, 2.0], selectableBolusVolumes)
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
