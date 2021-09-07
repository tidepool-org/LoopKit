//
//  GlucoseValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit


let MetadataKeyGlucoseIsDisplayOnly = "com.loudnate.GlucoseKit.HKMetadataKey.GlucoseIsDisplayOnly"
let MetadataKeyGlucoseConditionTitle = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseConditionTitle"
let MetadataKeyGlucoseConditionThresholdUnit = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseConditionThresholdUnit"
let MetadataKeyGlucoseConditionThresholdValue = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseConditionThresholdValue"
let MetadataKeyGlucoseTrend = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrend"
let MetadataKeyGlucoseTrendRateUnit = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrendRateUnit"
let MetadataKeyGlucoseTrendRateValue = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrendRateValue"


extension HKQuantitySample: GlucoseSampleValue {
    public var provenanceIdentifier: String {
        return sourceRevision.source.bundleIdentifier
    }

    public var isDisplayOnly: Bool {
        return metadata?[MetadataKeyGlucoseIsDisplayOnly] as? Bool ?? false
    }

    public var wasUserEntered: Bool {
        return metadata?[HKMetadataKeyWasUserEntered] as? Bool ?? false
    }

    public var condition: GlucoseCondition? {
        guard let title = metadata?[MetadataKeyGlucoseConditionTitle] as? String else {
            return nil
        }
        return GlucoseCondition(title: title, threshold: conditionThreshold)
    }

    private var conditionThreshold: HKQuantity? {
        guard let thresholdUnit = metadata?[MetadataKeyGlucoseConditionThresholdUnit] as? String,
              let thresholdValue = metadata?[MetadataKeyGlucoseConditionThresholdValue] as? Double else {
            return nil
        }
        return HKQuantity(unit: HKUnit(from: thresholdUnit), doubleValue: thresholdValue)
    }
    
    public var trend: GlucoseTrend? {
        return (metadata?[MetadataKeyGlucoseTrend] as? Int).flatMap { GlucoseTrend(rawValue: $0) }
    }

    public var trendRate: HKQuantity? {
        guard let trendRateUnit = metadata?[MetadataKeyGlucoseTrendRateUnit] as? String,
              let trendRateValue = metadata?[MetadataKeyGlucoseTrendRateValue] as? Double else {
            return nil
        }
        return HKQuantity(unit: HKUnit(from: trendRateUnit), doubleValue: trendRateValue)
    }
}
