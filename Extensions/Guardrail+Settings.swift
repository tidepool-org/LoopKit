//
//  Guardrail+Settings.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit

public extension Guardrail where Value == HKQuantity {
    static let suspendThreshold = Guardrail(absoluteBounds: 67...110, recommendedBounds: 74...80, unit: .milligramsPerDeciliter)

    static func maxSuspendThresholdValue(correctionRangeSchedule: GlucoseRangeSchedule?, preMealTargetRange: DoubleRange?, workoutTargetRange: DoubleRange?, unit: HKUnit) -> HKQuantity {

        return [
            suspendThreshold.absoluteBounds.upperBound.doubleValue(for: unit),
            correctionRangeSchedule?.minLowerBound().doubleValue(for: unit),
            preMealTargetRange?.minValue,
            workoutTargetRange?.minValue
        ]
        .compactMap { $0 }
        .min()
        .map { HKQuantity(unit: unit, doubleValue: $0) }!
    }

    static let correctionRange = Guardrail(absoluteBounds: 87...180, recommendedBounds: 101...115, unit: .milligramsPerDeciliter)

    static func minCorrectionRangeValue(suspendThreshold: GlucoseThreshold?, unit: HKUnit) -> HKQuantity {
        return [
            correctionRange.absoluteBounds.lowerBound.doubleValue(for: unit),
            suspendThreshold?.value
        ]
        .compactMap { $0 }
        .max()
        .map { HKQuantity(unit: unit, doubleValue: $0) }!
    }
    
    fileprivate static func workoutCorrectionRange(correctionRangeScheduleRange: ClosedRange<HKQuantity>,
                                                   suspendThreshold: GlucoseThreshold?,
                                                   unit: HKUnit) -> Guardrail<HKQuantity> {
        // Static "unconstrained" constant values before applying constraints
        let workoutCorrectionRange = Guardrail(absoluteBounds: 85...250, recommendedBounds: 101...180, unit: .milligramsPerDeciliter)
        
        let absoluteLowerBound = [
            workoutCorrectionRange.absoluteBounds.lowerBound.doubleValue(for: unit),
            suspendThreshold?.value
        ]
        .compactMap { $0 }
        .max()
        .map { HKQuantity(unit: unit, doubleValue: $0) }!
        let recommmendedLowerBound = max(absoluteLowerBound, correctionRangeScheduleRange.upperBound)
        return Guardrail(
            absoluteBounds: absoluteLowerBound...workoutCorrectionRange.absoluteBounds.upperBound,
            recommendedBounds: recommmendedLowerBound...workoutCorrectionRange.recommendedBounds.upperBound
        )
    }
    
    fileprivate static func preMealCorrectionRange(correctionRangeScheduleRange: ClosedRange<HKQuantity>,
                                                   suspendThreshold: GlucoseThreshold?,
                                                   unit: HKUnit) -> Guardrail<HKQuantity> {
        let premealCorrectionRangeMaximum = HKQuantity(unit: unit, doubleValue: 130.0)
        let absoluteLowerBound = suspendThreshold?.quantity ?? Guardrail.suspendThreshold.absoluteBounds.lowerBound
        return Guardrail(
            absoluteBounds: absoluteLowerBound...premealCorrectionRangeMaximum,
            recommendedBounds: absoluteLowerBound...min(max(absoluteLowerBound, correctionRangeScheduleRange.lowerBound), premealCorrectionRangeMaximum)
        )
    }
    
    static func correctionRangeOverride(for preset: CorrectionRangeOverrides.Preset,
                                        correctionRangeScheduleRange: ClosedRange<HKQuantity>,
                                        suspendThreshold: GlucoseThreshold?, unit: HKUnit) -> Guardrail {
        
        switch preset {
        case .workout:
            return workoutCorrectionRange(correctionRangeScheduleRange: correctionRangeScheduleRange, suspendThreshold: suspendThreshold, unit: unit)
        case .preMeal:
            return preMealCorrectionRange(correctionRangeScheduleRange: correctionRangeScheduleRange, suspendThreshold: suspendThreshold, unit: unit)
        }
    }
    
    static let insulinSensitivity = Guardrail(
        absoluteBounds: 10...500,
        recommendedBounds: 16...399,
        unit: HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit())
    )
 
    static let absoluteMinimumCarbRatio = 2.0
    static let carbRatio = Guardrail(
        absoluteBounds: absoluteMinimumCarbRatio...150,
        recommendedBounds: 4...28,
        unit: .gramsPerUnit
    )

    static func basalRate(supportedBasalRates: [Double]) -> Guardrail {
        let scheduledBasalRateAbsoluteRange = 0.05...30.0
        let recommendedLowerBound = supportedBasalRates.first == 0
            ? supportedBasalRates.dropFirst().first!
            : supportedBasalRates.first!
        return Guardrail(
            absoluteBounds: (supportedBasalRates.first!...supportedBasalRates.last!).clamped(to: scheduledBasalRateAbsoluteRange),
            recommendedBounds: (recommendedLowerBound...supportedBasalRates.last!).clamped(to: scheduledBasalRateAbsoluteRange),
            unit: .internationalUnitsPerHour
        )
    }

    static func maximumBasalRate(
        supportedBasalRates: [Double],
        scheduledBasalRange: ClosedRange<Double>?,
        lowestCarbRatio: Double?,
        maximumBasalRatePrecision decimalPlaces: Int = 3
    ) -> Guardrail {
        
        let maximum = 70.0 / (lowestCarbRatio ?? absoluteMinimumCarbRatio)
        
        let recommendedHighScheduledBasalScaleFactor = 6.4
        let recommendedLowScheduledBasalScaleFactor = 2.1

        let recommendedLowerBound: Double
        let recommendedUpperBound: Double
        if let highestScheduledBasalRate = scheduledBasalRange?.upperBound {
            let lowWarning = (recommendedLowScheduledBasalScaleFactor * highestScheduledBasalRate).matchingOrTruncatedValue(from: supportedBasalRates, withinDecimalPlaces: decimalPlaces)
            let highWarning = (recommendedHighScheduledBasalScaleFactor * highestScheduledBasalRate).matchingOrTruncatedValue(from: supportedBasalRates, withinDecimalPlaces: decimalPlaces)
            
            recommendedLowerBound = lowWarning
            recommendedUpperBound = highestScheduledBasalRate == 0
                ? recommendedLowerBound
                : highWarning
            
            let absoluteBounds = highestScheduledBasalRate...maximum
            let recommendedBounds = (recommendedLowerBound...recommendedUpperBound).clamped(to: absoluteBounds)
            return Guardrail(
                absoluteBounds: absoluteBounds,
                recommendedBounds: recommendedBounds,
                unit: .internationalUnitsPerHour
            )

        } else {
            return Guardrail(
                absoluteBounds: supportedBasalRates.first!...maximum,
                recommendedBounds:  supportedBasalRates.first!...maximum,
                unit: .internationalUnitsPerHour
            )
        }
    }

    static func maximumBolus(supportedBolusVolumes: [Double]) -> Guardrail {
        let maxBolusWarningThresholdUnits: Double = 20
        let minimumSupportedBolusVolume = supportedBolusVolumes.first!
        let recommendedLowerBound = minimumSupportedBolusVolume == 0 ? supportedBolusVolumes.dropFirst().first! : minimumSupportedBolusVolume
        let recommendedUpperBound = min(maxBolusWarningThresholdUnits.nextDown, supportedBolusVolumes.last!)
        return Guardrail(
            absoluteBounds: supportedBolusVolumes.first!...supportedBolusVolumes.last!,
            recommendedBounds: recommendedLowerBound...recommendedUpperBound,
            unit: .internationalUnit()
        )
    }
}
