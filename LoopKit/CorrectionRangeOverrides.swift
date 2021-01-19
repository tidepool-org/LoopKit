//
//  CorrectionRangeOverrides.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import Foundation

public struct CorrectionRangeOverrides: Equatable {
    public enum Preset: Hashable, CaseIterable {
        case preMeal
        case workout
    }

    public var ranges: [Preset: ClosedRange<HKQuantity>]

    public init(preMeal: DoubleRange?, workout: DoubleRange?, unit: HKUnit) {
        ranges = [:]
        ranges[.preMeal] = preMeal?.quantityRange(for: unit)
        ranges[.workout] = workout?.quantityRange(for: unit)
    }

    public init(preMeal: ClosedRange<HKQuantity>?, workout: ClosedRange<HKQuantity>?) {
        ranges = [:]
        ranges[.preMeal] = preMeal
        ranges[.workout] = workout
    }

    public var preMeal: ClosedRange<HKQuantity>? { ranges[.preMeal] }
    public var workout: ClosedRange<HKQuantity>? { ranges[.workout] }
}

public extension CorrectionRangeOverrides.Preset {
    var title: String {
        switch self {
        case .preMeal:
            return LocalizedString("Pre-Meal", comment: "Title for pre-meal mode")
        case .workout:
            return LocalizedString("Workout", comment: "Title for workout mode")
        }
    }
    
    var therapySetting: TherapySetting {
        switch self {
        case .preMeal: return .preMealCorrectionRangeOverride
        case .workout: return .workoutCorrectionRangeOverride
        }
    }
}

extension CorrectionRangeOverrides: Codable {
    fileprivate var codingGlucoseUnit: HKUnit {
        return .milligramsPerDeciliter
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let preMealDoubleRange = try container.decodeIfPresent(DoubleRange.self, forKey: .preMealRange)
        let workoutDoubleRange = try container.decodeIfPresent(DoubleRange.self, forKey: .workoutRange)
        let bloodGlucoseUnit = HKUnit(from: try container.decode(String.self, forKey: .bloodGlucoseUnit))

        self.ranges = [:]
        self.ranges[.preMeal] = preMealDoubleRange?.quantityRange(for: bloodGlucoseUnit)
        self.ranges[.workout] = workoutDoubleRange?.quantityRange(for: bloodGlucoseUnit)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let preMealDoubleRange = preMeal?.doubleRange(for: codingGlucoseUnit)
        let workoutDoubleRange = workout?.doubleRange(for: codingGlucoseUnit)
        try container.encodeIfPresent(preMealDoubleRange, forKey: .preMealRange)
        try container.encodeIfPresent(workoutDoubleRange, forKey: .workoutRange)
        try container.encode(codingGlucoseUnit.unitString, forKey: .bloodGlucoseUnit)
    }

    private enum CodingKeys: String, CodingKey {
        case preMealRange
        case workoutRange
        case bloodGlucoseUnit
    }
}

extension CorrectionRangeOverrides: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let bloodGlucoseUnitString = rawValue["bloodGlucoseUnit"] as? String else {
            return nil
        }

        let bloodGlucoseUnit = HKUnit(from: bloodGlucoseUnitString)

        ranges = [:]
        if let rawPreMealTargetRange = rawValue["preMealTargetRange"] as? DoubleRange.RawValue {
            ranges[.preMeal] = DoubleRange(rawValue: rawPreMealTargetRange)?.quantityRange(for: bloodGlucoseUnit)
        }

        if let rawWorkoutTargetRange = rawValue["workoutTargetRange"] as? DoubleRange.RawValue {
            ranges[.workout] = DoubleRange(rawValue: rawWorkoutTargetRange)?.quantityRange(for: bloodGlucoseUnit)
        }
    }

    public var rawValue: RawValue {
        let bloodGlucoseUnit = codingGlucoseUnit
        let preMealTargetDoubleRange = preMeal?.doubleRange(for: bloodGlucoseUnit)
        let workoutTargetDoubleRange = workout?.doubleRange(for: bloodGlucoseUnit)
        var raw: RawValue = [
            "bloodGlucoseUnit": bloodGlucoseUnit.unitString,
        ]

        raw["preMealTargetRange"] = preMealTargetDoubleRange?.rawValue
        raw["workoutTargetRange"] = workoutTargetDoubleRange?.rawValue

        return raw
    }
}
