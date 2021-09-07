//
//  GlucoseCondition.swift
//  LoopKit
//
//  Created by Darin Krauss on 9/3/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import HealthKit

public enum GlucoseCondition: Equatable, RawRepresentable {
    public typealias RawValue = [String: Any]

    case belowRange(threshold: HKQuantity? = nil)
    case aboveRange(threshold: HKQuantity? = nil)

    public init?(title: String, threshold: HKQuantity? = nil) {
        switch title {
        case "belowRange":
            self = .belowRange(threshold: threshold)
        case "aboveRange":
            self = .aboveRange(threshold: threshold)
        default:
            return nil
        }
    }

    public init?(rawValue: RawValue) {
        guard let title = rawValue["title"] as? String else {
            return nil
        }

        let threshold: HKQuantity? = {
            guard let thresholdUnit = rawValue["thresholdUnit"] as? String,
                  let thresholdValue = rawValue["thresholdValue"] as? Double else {
                return nil
            }
            return HKQuantity(unit: HKUnit(from: thresholdUnit), doubleValue: thresholdValue)
        }()

        self.init(title: title, threshold: threshold)
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "title": title
        ]

        if let threshold = threshold {
            rawValue["thresholdUnit"] = HKUnit.milligramsPerDeciliter.unitString
            rawValue["thresholdValue"] = threshold.doubleValue(for: .milligramsPerDeciliter)
        }

        return rawValue
    }

    public var title: String {
        switch self {
        case .belowRange:
            return "belowRange"
        case .aboveRange:
            return "aboveRange"
        }
    }

    public var threshold: HKQuantity? {
        switch self {
        case .belowRange(let threshold):
            return threshold
        case .aboveRange(let threshold):
            return threshold
        }
    }
}

