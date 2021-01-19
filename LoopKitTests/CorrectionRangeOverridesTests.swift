//
//  CorrectionRangeOverridesTests.swift
//  LoopKitTests
//
//  Created by Nathaniel Hamming on 2021-03-12.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class CorrectionRangeOverridesTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testInitializerDouble() throws {
        let unit = HKUnit.milligramsPerDeciliter
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 75, maxValue: 90),
            workout: DoubleRange(minValue: 80, maxValue: 100),
            unit: unit)

        var expectedRanges: [CorrectionRangeOverrides.Preset: ClosedRange<HKQuantity>] = [:]
        expectedRanges[.preMeal] = DoubleRange(minValue: 75, maxValue: 90).quantityRange(for: unit)
        expectedRanges[.workout] = DoubleRange(minValue: 80, maxValue: 100).quantityRange(for: unit)

        XCTAssertEqual(correctionRangeOverrides.ranges, expectedRanges)
        XCTAssertEqual(correctionRangeOverrides.preMeal, expectedRanges[.preMeal])
        XCTAssertEqual(correctionRangeOverrides.workout, expectedRanges[.workout])
    }

    func testInitializerQuantity() throws {
        let unit = HKUnit.millimolesPerLiter
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 4.0, maxValue: 5.0).quantityRange(for: unit),
            workout: DoubleRange(minValue: 4.5, maxValue: 6.0).quantityRange(for: unit))

        var expectedRanges: [CorrectionRangeOverrides.Preset: ClosedRange<HKQuantity>] = [:]
        expectedRanges[.preMeal] = DoubleRange(minValue: 4.0, maxValue: 5.0).quantityRange(for: unit)
        expectedRanges[.workout] = DoubleRange(minValue: 4.5, maxValue: 6.0).quantityRange(for: unit)

        XCTAssertEqual(correctionRangeOverrides.ranges, expectedRanges)
        XCTAssertEqual(correctionRangeOverrides.preMeal, expectedRanges[.preMeal])
        XCTAssertEqual(correctionRangeOverrides.workout, expectedRanges[.workout])
    }

    func testPresetTitle() throws {
        XCTAssertEqual(CorrectionRangeOverrides.Preset.preMeal.title, "Pre-Meal")
        XCTAssertEqual(CorrectionRangeOverrides.Preset.workout.title, "Workout")
    }

    func testPresetTherapySettings() throws {
        XCTAssertEqual(CorrectionRangeOverrides.Preset.preMeal.therapySetting, .preMealCorrectionRangeOverride)
        XCTAssertEqual(CorrectionRangeOverrides.Preset.workout.therapySetting, .workoutCorrectionRangeOverride)
    }

    let encodedString = """
    {
      "bloodGlucoseUnit" : "mg/dL",
      "preMealRange" : {
        "maxValue" : 90,
        "minValue" : 75
      },
      "workoutRange" : {
        "maxValue" : 100,
        "minValue" : 80
      }
    }
    """

    func testEncoding() throws {
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 75, maxValue: 90),
            workout: DoubleRange(minValue: 80, maxValue: 100),
            unit: .milligramsPerDeciliter)
        let data = try encoder.encode(correctionRangeOverrides)
        XCTAssertEqual(encodedString, String(data: data, encoding: .utf8)!)
    }

    func testDecoding() throws {
        let data = encodedString.data(using: .utf8)!
        let decoded = try decoder.decode(CorrectionRangeOverrides.self, from: data)
        let expected = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 75, maxValue: 90),
            workout: DoubleRange(minValue: 80, maxValue: 100),
            unit: .milligramsPerDeciliter)

        XCTAssertEqual(expected, decoded)
        XCTAssertEqual(decoded.ranges, expected.ranges)
    }

    func testRawValue() throws {
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 75, maxValue: 90),
            workout: DoubleRange(minValue: 80, maxValue: 100),
            unit: .milligramsPerDeciliter)
        var expectedRawValue: [String:Any] = [:]
        expectedRawValue["bloodGlucoseUnit"] = "mg/dL"
        expectedRawValue["preMealTargetRange"] = DoubleRange(minValue: 75, maxValue: 90).rawValue
        expectedRawValue["workoutTargetRange"] = DoubleRange(minValue: 80, maxValue: 100).rawValue

        XCTAssertEqual(correctionRangeOverrides.rawValue["bloodGlucoseUnit"] as? String, expectedRawValue["bloodGlucoseUnit"] as? String)
        XCTAssertEqual(correctionRangeOverrides.rawValue["preMealTargetRange"] as? DoubleRange.RawValue, expectedRawValue["preMealTargetRange"] as? DoubleRange.RawValue)
        XCTAssertEqual(correctionRangeOverrides.rawValue["workoutTargetRange"] as? DoubleRange.RawValue, expectedRawValue["workoutTargetRange"] as? DoubleRange.RawValue)
    }

    func testInitializeFromRawValue() throws {
        var rawValue: [String:Any] = [:]
        rawValue["bloodGlucoseUnit"] = "mg/dL"
        rawValue["preMealTargetRange"] = DoubleRange(minValue: 80, maxValue: 100).rawValue
        rawValue["workoutTargetRange"] = DoubleRange(minValue: 110, maxValue: 130).rawValue

        let correctionRangeOverrides = CorrectionRangeOverrides(rawValue: rawValue)
        var expectedRanges: [CorrectionRangeOverrides.Preset: ClosedRange<HKQuantity>] = [:]
        expectedRanges[.preMeal] = DoubleRange(minValue: 80, maxValue: 100).quantityRange(for: .milligramsPerDeciliter)
        expectedRanges[.workout] = DoubleRange(minValue: 110, maxValue: 130).quantityRange(for: .milligramsPerDeciliter)
        XCTAssertEqual(correctionRangeOverrides?.ranges, expectedRanges)
    }
}
