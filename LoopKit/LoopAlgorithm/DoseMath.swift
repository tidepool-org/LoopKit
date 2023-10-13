//
//  DoseMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/8/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit

public enum InsulinCorrection {
    case inRange
    case aboveRange(min: GlucoseValue, correcting: GlucoseValue, minTarget: HKQuantity, units: Double)
    case entirelyBelowRange(min: GlucoseValue, minTarget: HKQuantity, units: Double)
    case suspend(min: GlucoseValue)
}

extension InsulinCorrection {
    /// The delivery units for the correction
    private var units: Double {
        switch self {
        case .aboveRange(min: _, correcting: _, minTarget: _, units: let units):
            return units
        case .entirelyBelowRange(min: _, minTarget: _, units: let units):
            return units
        case .inRange, .suspend:
            return 0
        }
    }

    /// Determines the temp basal over `duration` needed to perform the correction.
    ///
    /// - Parameters:
    ///   - scheduledBasalRate: The scheduled basal rate at the time the correction is delivered
    ///   - maxBasalRate: The maximum allowed basal rate
    ///   - duration: The duration of the temporary basal
    ///   - rateRounder: The smallest fraction of a unit supported in basal delivery
    /// - Returns: A temp basal recommendation
    public func asTempBasal(
        scheduledBasalRate: Double,
        maxBasalRate: Double,
        duration: TimeInterval,
        rateRounder: ((Double) -> Double)?
    ) -> TempBasalRecommendation {
        var rate = units / (duration / TimeInterval(hours: 1))  // units/hour
        switch self {
        case .aboveRange, .inRange, .entirelyBelowRange:
            rate += scheduledBasalRate
        case .suspend:
            break
        }

        rate = Swift.min(maxBasalRate, Swift.max(0, rate))

        rate = rateRounder?(rate) ?? rate

        return TempBasalRecommendation(
            unitsPerHour: rate,
            duration: duration
        )
    }

    private var bolusRecommendationNotice: BolusRecommendationNotice? {
        switch self {
        case .suspend(min: let minimum):
            return .glucoseBelowSuspendThreshold(minGlucose: minimum)
        case .inRange:
            return .predictedGlucoseInRange
        case .entirelyBelowRange(min: let min, minTarget: _, units: _):
            return .allGlucoseBelowTarget(minGlucose: min)
        case .aboveRange(min: let min, correcting: _, minTarget: let target, units: let units):
            if units > 0 && min.quantity < target {
                return .predictedGlucoseBelowTarget(minGlucose: min)
            } else {
                return nil
            }
        }
    }

    /// Determines the bolus needed to perform the correction, subtracting any insulin already scheduled for
    ///  delivery, such as the remaining portion of an ongoing temp basal.
    ///
    /// - Parameters:
    ///   - pendingInsulin: The number of units expected to be delivered, but not yet reflected in the correction
    ///   - maxBolus: The maximum allowable bolus value in units
    /// - Returns: A bolus recommendation
    public func asManualBolus(maxBolus: Double) -> ManualBolusRecommendation {
        return ManualBolusRecommendation(
            amount: Swift.min(maxBolus, Swift.max(0, units)),
            notice: bolusRecommendationNotice
        )
    }

    /// Determines the bolus amount to perform a partial application correction
    ///
    /// - Parameters:
    ///   - partialApplicationFactor: The fraction of needed insulin to deliver now
    ///   - maxBolus: The maximum allowable bolus value in units
    ///   - volumeRounder: Method to round computed dose to deliverable volume
    /// - Returns: A bolus recommendation
    public func asPartialBolus(
        partialApplicationFactor: Double,
        maxBolusUnits: Double,
        volumeRounder: ((Double) -> Double)?
    ) -> Double {

        let partialDose = units * partialApplicationFactor

        return Swift.min(Swift.max(0, volumeRounder?(partialDose) ?? partialDose),volumeRounder?(maxBolusUnits) ?? maxBolusUnits)
    }
}


extension TempBasalRecommendation {
    /// Equates the recommended rate with another rate
    ///
    /// - Parameter unitsPerHour: The rate to compare
    /// - Returns: Whether the rates are equal within Double precision
    private func matchesRate(_ unitsPerHour: Double) -> Bool {
        return abs(self.unitsPerHour - unitsPerHour) < .ulpOfOne
    }

    /// Determines whether the recommendation is necessary given the current state of the pump
    ///
    /// - Parameters:
    ///   - date: The date the recommendation would be delivered
    ///   - scheduledBasalRate: The scheduled basal rate at `date`
    ///   - lastTempBasal: The previously set temp basal
    ///   - continuationInterval: The duration of time before an ongoing temp basal should be continued with a new command
    ///   - scheduledBasalRateMatchesPump: A flag describing whether `scheduledBasalRate` matches the scheduled basal rate of the pump.
    ///                                    If `false` and the recommendation matches `scheduledBasalRate`, the temp will be recommended
    ///                                    at the scheduled basal rate rather than recommending no temp.
    /// - Returns: A temp basal recommendation
    public func ifNecessary(
        at date: Date,
        scheduledBasalRate: Double,
        lastTempBasal: DoseEntry?,
        continuationInterval: TimeInterval,
        scheduledBasalRateMatchesPump: Bool
    ) -> TempBasalRecommendation? {
        // Adjust behavior for the currently active temp basal
        if let lastTempBasal = lastTempBasal,
            lastTempBasal.type == .tempBasal,
            lastTempBasal.endDate > date
        {
            /// If the last temp basal has the same rate, and has more than `continuationInterval` of time remaining, don't set a new temp
            if matchesRate(lastTempBasal.unitsPerHour),
                lastTempBasal.endDate.timeIntervalSince(date) > continuationInterval {
                return nil
            } else if matchesRate(scheduledBasalRate), scheduledBasalRateMatchesPump {
                // If our new temp matches the scheduled rate of the pump, cancel the current temp
                return .cancel
            }
        } else if matchesRate(scheduledBasalRate), scheduledBasalRateMatchesPump {
            // If we recommend the in-progress scheduled basal rate of the pump, do nothing
            return nil
        }

        return self
    }
}

/// Computes a total insulin amount necessary to correct a glucose differential at a given sensitivity
///
/// - Parameters:
///   - fromValue: The starting glucose value
///   - toValue: The desired glucose value
///   - effectedSensitivity: The sensitivity, in glucose-per-insulin-unit
/// - Returns: The insulin correction in units
private func insulinCorrectionUnits(fromValue: Double, toValue: Double, effectedSensitivity: Double) -> Double {
    guard effectedSensitivity > 0 else {
        preconditionFailure("Negative effected sensitivity: \(effectedSensitivity)")
    }

    let glucoseCorrection = fromValue - toValue

    return glucoseCorrection / effectedSensitivity
}

/// Computes a target glucose value for a correction, at a given time during the insulin effect duration
///
/// - Parameters:
///   - percentEffectDuration: The percent of time elapsed of the insulin effect duration
///   - minValue: The minimum (starting) target value
///   - maxValue: The maximum (eventual) target value
/// - Returns: A target value somewhere between the minimum and maximum
private func targetGlucoseValue(percentEffectDuration: Double, minValue: Double, maxValue: Double) -> Double {
    // The inflection point in time: before it we use minValue, after it we linearly blend from minValue to maxValue
    let useMinValueUntilPercent = 0.5

    guard percentEffectDuration > useMinValueUntilPercent else {
        return minValue
    }

    guard percentEffectDuration < 1 else {
        return maxValue
    }

    let slope = (maxValue - minValue) / (1 - useMinValueUntilPercent)
    return minValue + slope * (percentEffectDuration - useMinValueUntilPercent)
}


extension Collection where Element: GlucoseValue {
    @available(*, deprecated, message: "Being replaced by method using timelines for correction range and sensitivity")
    /// For a collection of glucose prediction, determine the least amount of insulin delivered at
    /// `date` to correct the predicted glucose to the middle of `correctionRange` at the time of prediction.
    ///
    /// - Parameters:
    ///   - correctionRange: The schedule of glucose values used for correction
    ///   - date: The date the insulin correction is delivered
    ///   - suspendThreshold: The glucose value below which only suspension is returned
    ///   - sensitivity: The insulin sensitivity at the time of delivery
    ///   - model: The insulin effect model
    /// - Returns: A correction value in units, or nil if no correction needed
    private func insulinCorrection(
        to correctionRange: GlucoseRangeSchedule,
        at date: Date,
        suspendThreshold: HKQuantity,
        sensitivity: HKQuantity,
        model: InsulinModel
    ) -> InsulinCorrection? {
        let effectDuration = model.effectDuration
        let endDate = date.addingTimeInterval(effectDuration)
        let sensitivityTimeline = [AbsoluteScheduleValue(startDate: date, endDate: endDate, value: sensitivity)]
        let correctionRangeTimeline = correctionRange.quantityBetween(start: date, end: endDate)
        return insulinCorrection(
            to: correctionRangeTimeline,
            at: date,
            suspendThreshold: suspendThreshold,
            insulinSensitivity: sensitivityTimeline,
            model: model)
    }

    /// For a collection of glucose prediction, determine the least amount of insulin delivered at
    /// `date` to correct the predicted glucose to the middle of `correctionRange` at the time of prediction.
    ///
    /// - Parameters:
    ///   - correctionRange: The timeline of glucose ranges used for correction
    ///   - date: The date the insulin correction is delivered
    ///   - suspendThreshold: The glucose value below which only suspension is returned
    ///   - insulinSensitivityTimeline: The timeline of expected insulin sensitivity over the period of dose absorption
    ///   - model: The insulin effect model
    /// - Returns: A correction value in units, or nil if no correction needed
    public func insulinCorrection(
        to correctionRange: GlucoseRangeTimeline,
        at date: Date,
        suspendThreshold: HKQuantity,
        insulinSensitivity: [AbsoluteScheduleValue<HKQuantity>],
        model: InsulinModel
    ) -> InsulinCorrection {
        var minGlucose: GlucoseValue!
        var eventualGlucose: GlucoseValue!
        var correctingGlucose: GlucoseValue?
        var minCorrectionUnits: Double?
        var effectedSensitivityAtMinGlucose: Double?

        // Only consider predictions within the model's effect duration
        let validDateRange = DateInterval(start: date, duration: model.effectDuration)

        let unit = HKUnit.milligramsPerDeciliter

        guard self.count > 0 else {
            preconditionFailure("Unable to compute correction for empty glucose array")
        }

        let suspendThresholdValue = suspendThreshold.doubleValue(for: unit)

        // For each prediction above target, determine the amount of insulin necessary to correct glucose based on the modeled effectiveness of the insulin at that time
        for prediction in self {
            guard validDateRange.contains(prediction.startDate) else {
                continue
            }


            // If any predicted value is below the suspend threshold, return immediately
            guard prediction.quantity >= suspendThreshold else {
                print("Suspend!")
                return .suspend(min: prediction)
            }

            eventualGlucose = prediction

            let predictedGlucoseValue = prediction.quantity.doubleValue(for: unit)
            let time = prediction.startDate.timeIntervalSince(date)

            guard let correctionRangeItem = correctionRange.closestPrior(to: prediction.startDate) else {
                preconditionFailure("Correction range must cover date: \(prediction.startDate)")
            }

            // Compute the target value as a function of time since the dose started
            let targetValue = targetGlucoseValue(
                percentEffectDuration: time / model.effectDuration,
                minValue: suspendThresholdValue,
                maxValue: correctionRangeItem.value.averageValue(for: unit)
            )

            // Compute the dose required to bring this prediction to target:
            // dose = (Glucose Δ) / (% effect × sensitivity)

            let isfSegments = insulinSensitivity.filterDateRange(date, prediction.startDate)

            let effectedSensitivity = isfSegments.reduce(0) { partialResult, segment in
                let start = Swift.max(date, segment.startDate).timeIntervalSince(date)
                let end = Swift.min(prediction.startDate, segment.endDate).timeIntervalSince(date)
                let percentEffected = model.percentEffectRemaining(at: start) - model.percentEffectRemaining(at: end)
                return percentEffected * segment.value.doubleValue(for: unit)
            }

            // Update range statistics
            if minGlucose == nil || prediction.quantity < minGlucose!.quantity {
                minGlucose = prediction
                effectedSensitivityAtMinGlucose = effectedSensitivity
            }

            let correctionUnits = insulinCorrectionUnits(
                fromValue: predictedGlucoseValue,
                toValue: targetValue,
                effectedSensitivity: Swift.max(.ulpOfOne, effectedSensitivity)
            )

            guard correctionUnits > 0 else {
                continue
            }

            // Update the correction only if we've found a new minimum
            guard minCorrectionUnits == nil || correctionUnits < minCorrectionUnits! else {
                continue
            }

            correctingGlucose = prediction
            minCorrectionUnits = correctionUnits
        }

        // Choose either the minimum glucose or eventual glucose as the correction delta
        let minGlucoseTargets = correctionRange.closestPrior(to: minGlucose.startDate)!.value
        let eventualGlucoseTargets = correctionRange.closestPrior(to: eventualGlucose.startDate)!.value

        // Treat the mininum glucose when both are below range
        if minGlucose.quantity < minGlucoseTargets.lowerBound &&
            eventualGlucose.quantity < eventualGlucoseTargets.lowerBound
        {
            let units = insulinCorrectionUnits(
                fromValue: minGlucose.quantity.doubleValue(for: unit),
                toValue: minGlucoseTargets.averageValue(for: unit),
                effectedSensitivity: Swift.max(.ulpOfOne, effectedSensitivityAtMinGlucose!)
            )

            return .entirelyBelowRange(
                min: minGlucose,
                minTarget: minGlucoseTargets.lowerBound,
                units: units
            )
        } else if eventualGlucose.quantity > eventualGlucoseTargets.upperBound,
            let minCorrectionUnits = minCorrectionUnits, let correctingGlucose = correctingGlucose
        {
            return .aboveRange(
                min: minGlucose,
                correcting: correctingGlucose,
                minTarget: eventualGlucoseTargets.lowerBound,
                units: minCorrectionUnits
            )
        } else {
            return .inRange
        }
    }

    /// Recommends a temporary basal rate to conform a glucose prediction timeline to a correction range
    ///
    /// Returns nil if the normal scheduled basal, or active temporary basal, is sufficient.
    ///
    /// - Parameters:
    ///   - correctionRange: The schedule of correction ranges
    ///   - date: The date at which the temp basal would be scheduled, defaults to now
    ///   - suspendThreshold: A glucose value causing a recommendation of no insulin if any prediction falls below
    ///   - sensitivity: The schedule of insulin sensitivities
    ///   - model: The insulin absorption model
    ///   - basalRates: The schedule of basal rates
    ///   - additionalActiveInsulinClamp: Max amount of additional insulin above scheduled basal rate allowed to be scheduled
    ///   - maxBasalRate: The maximum allowed basal rate
    ///   - lastTempBasal: The previously set temp basal
    ///   - rateRounder: Closure that rounds recommendation to nearest supported rate. If nil, no rounding is performed
    ///   - isBasalRateScheduleOverrideActive: A flag describing whether a basal rate schedule override is in progress
    ///   - duration: The duration of the temporary basal
    ///   - continuationInterval: The duration of time before an ongoing temp basal should be continued with a new command
    /// - Returns: The recommended temporary basal rate and duration
    public func recommendedTempBasal(
        to correctionRange: GlucoseRangeSchedule,
        at date: Date = Date(),
        suspendThreshold: HKQuantity?,
        sensitivity: InsulinSensitivitySchedule,
        model: InsulinModel,
        basalRates: BasalRateSchedule,
        maxBasalRate: Double,
        additionalActiveInsulinClamp: Double? = nil,
        lastTempBasal: DoseEntry?,
        rateRounder: ((Double) -> Double)? = nil,
        isBasalRateScheduleOverrideActive: Bool = false,
        duration: TimeInterval = TimeInterval(30 * 60),
        continuationInterval: TimeInterval = TimeInterval(60 * 11)
    ) -> TempBasalRecommendation? {

        guard self.count > 0 else {
            return nil
        }

        let correction = self.insulinCorrection(
            to: correctionRange,
            at: date,
            suspendThreshold: suspendThreshold ?? correctionRange.quantityRange(at: date).lowerBound,
            sensitivity: sensitivity.quantity(at: date),
            model: model
        )

        let scheduledBasalRate = basalRates.value(at: date)
        var maxBasalRate = maxBasalRate

        // TODO: Allow `highBasalThreshold` to be a configurable setting
        if case .aboveRange(min: let min, correcting: _, minTarget: let highBasalThreshold, units: _)? = correction,
            min.quantity < highBasalThreshold
        {
            maxBasalRate = scheduledBasalRate
        }

        if let additionalActiveInsulinClamp {
            let maxThirtyMinuteRateToKeepIOBBelowLimit = additionalActiveInsulinClamp * 2.0 + scheduledBasalRate  // 30 minutes of a U/hr rate
            maxBasalRate = Swift.min(maxThirtyMinuteRateToKeepIOBBelowLimit, maxBasalRate)
        }

        let temp = correction?.asTempBasal(
            scheduledBasalRate: scheduledBasalRate,
            maxBasalRate: maxBasalRate,
            duration: duration,
            rateRounder: rateRounder
        )

        return temp?.ifNecessary(
            at: date,
            scheduledBasalRate: scheduledBasalRate,
            lastTempBasal: lastTempBasal,
            continuationInterval: continuationInterval,
            scheduledBasalRateMatchesPump: !isBasalRateScheduleOverrideActive
        )
    }


    @available(*, deprecated, message: "Being replaced by method using timelines for correction range, suspend threshold, and sensitivity")
    /// Recommends a dose suitable for automatic enactment. Uses boluses for high corrections, and temp basals for low corrections.
    ///
    /// Returns nil if the normal scheduled basal, or active temporary basal, is sufficient.
    ///
    /// - Parameters:
    ///   - correctionRange: The schedule of correction ranges
    ///   - date: The date at which the temp basal would be scheduled, defaults to now
    ///   - suspendThreshold: A glucose value causing a recommendation of no insulin if any prediction falls below
    ///   - sensitivity: The schedule of insulin sensitivities
    ///   - model: The insulin absorption model
    ///   - basalRates: The schedule of basal rates
    ///   - maxBasalRate: The maximum allowed basal rate
    ///   - lastTempBasal: The previously set temp basal
    ///   - rateRounder: Closure that rounds recommendation to nearest supported rate. If nil, no rounding is performed
    ///   - isBasalRateScheduleOverrideActive: A flag describing whether a basal rate schedule override is in progress
    ///   - duration: The duration of the temporary basal
    ///   - continuationInterval: The duration of time before an ongoing temp basal should be continued with a new command
    /// - Returns: The recommended dosing, or nil if no dose adjustment recommended
    public func recommendedAutomaticDose(
        to correctionRange: GlucoseRangeSchedule,
        at date: Date = Date(),
        suspendThreshold: HKQuantity?,
        sensitivity: InsulinSensitivitySchedule,
        model: InsulinModel,
        basalRates: BasalRateSchedule,
        maxAutomaticBolus: Double,
        partialApplicationFactor: Double,
        lastTempBasal: DoseEntry?,
        volumeRounder: ((Double) -> Double)? = nil,
        rateRounder: ((Double) -> Double)? = nil,
        isBasalRateScheduleOverrideActive: Bool = false,
        duration: TimeInterval = TimeInterval(30 * 60),
        continuationInterval: TimeInterval = TimeInterval(11 * 60)
    ) -> AutomaticDoseRecommendation? {
        guard let correction = self.insulinCorrection(
            to: correctionRange,
            at: date,
            suspendThreshold: suspendThreshold ?? correctionRange.quantityRange(at: date).lowerBound,
            sensitivity: sensitivity.quantity(at: date),
            model: model
        ) else {
            return nil
        }

        let scheduledBasalRate = basalRates.value(at: date)
        var maxAutomaticBolus = maxAutomaticBolus

        if case .aboveRange(min: let min, correcting: _, minTarget: let doseThreshold, units: _) = correction,
            min.quantity < doseThreshold
        {
            maxAutomaticBolus = 0
        }

        var temp: TempBasalRecommendation? = correction.asTempBasal(
            scheduledBasalRate: scheduledBasalRate,
            maxBasalRate: scheduledBasalRate,
            duration: duration,
            rateRounder: rateRounder
        )

        temp = temp?.ifNecessary(
            at: date,
            scheduledBasalRate: scheduledBasalRate,
            lastTempBasal: lastTempBasal,
            continuationInterval: continuationInterval,
            scheduledBasalRateMatchesPump: !isBasalRateScheduleOverrideActive
        )

        let bolusUnits = correction.asPartialBolus(
            partialApplicationFactor: partialApplicationFactor,
            maxBolusUnits: maxAutomaticBolus,
            volumeRounder: volumeRounder
        )

        if temp != nil || bolusUnits > 0 {
            return AutomaticDoseRecommendation(basalAdjustment: temp, bolusUnits: bolusUnits)
        }

        return nil
    }

    /// Recommends a bolus to conform a glucose prediction timeline to a correction range
    ///
    /// - Parameters:
    ///   - correctionRange: The schedule of correction ranges
    ///   - date: The date at which the bolus would apply, defaults to now
    ///   - suspendThreshold: A glucose value causing a recommendation of no insulin if any prediction falls below
    ///   - sensitivity: The schedule of insulin sensitivities
    ///   - model: The insulin absorption model
    ///   - pendingInsulin: The number of units expected to be delivered, but not yet reflected in the correction
    ///   - maxBolus: The maximum bolus to return
    ///   - volumeRounder: Closure that rounds recommendation to nearest supported bolus volume. If nil, no rounding is performed
    /// - Returns: A bolus recommendation
    public func recommendedManualBolus(
        to correctionRange: GlucoseRangeSchedule,
        at date: Date = Date(),
        suspendThreshold: HKQuantity?,
        sensitivity: InsulinSensitivitySchedule,
        model: InsulinModel,
        maxBolus: Double
    ) -> ManualBolusRecommendation {

        guard self.count > 0 else {
            return .init(amount: 0)
        }

        guard let correction = self.insulinCorrection(
            to: correctionRange,
            at: date,
            suspendThreshold: suspendThreshold ?? correctionRange.quantityRange(at: date).lowerBound,
            sensitivity: sensitivity.quantity(at: date),
            model: model
        ) else {
            return ManualBolusRecommendation(amount: 0)
        }

        var bolus = correction.asManualBolus(maxBolus: maxBolus)

        // Handle the "current BG below target" notice here
        // TODO: Don't assume in the future that the first item in the array is current BG
        if case .predictedGlucoseBelowTarget? = bolus.notice,
            let first = first, first.quantity < correctionRange.quantityRange(at: first.startDate).lowerBound
        {
            bolus.notice = .currentGlucoseBelowTarget(glucose: first)
        }

        return bolus
    }

    /// Recommends a bolus to conform a glucose prediction timeline to a correction range
    ///
    /// - Parameters:
    ///   - correctionRange: The timeline of correction ranges
    ///   - date: The date at which the bolus would apply, defaults to now
    ///   - suspendThreshold: A glucose value causing a recommendation of no insulin if any prediction falls below
    ///   - insulinSensitivity: The timeline of insulin sensitivities
    ///   - model: The insulin absorption model to be used for the recommended dose
    ///   - pendingInsulin: The number of units expected to be delivered, but not yet reflected in the correction
    ///   - maxBolus: The maximum bolus to return
    /// - Returns: A bolus recommendation
    public func recommendedManualBolus(
        to correctionRangeTimeline: GlucoseRangeTimeline,
        at date: Date = Date(),
        suspendThreshold: HKQuantity,
        insulinSensitivity: [AbsoluteScheduleValue<HKQuantity>],
        model: InsulinModel,
        maxBolus: Double
    ) -> ManualBolusRecommendation {
        let correction = self.insulinCorrection(
            to: correctionRangeTimeline,
            at: date,
            suspendThreshold: suspendThreshold,
            insulinSensitivity: insulinSensitivity,
            model: model
        )

        var bolus = correction.asManualBolus(maxBolus: maxBolus)

        // Handle the "current BG below target" notice here
        // TODO: Don't assume in the future that the first item in the array is current BG
        if case .predictedGlucoseBelowTarget? = bolus.notice,
           let first = first, first.quantity < correctionRangeTimeline.closestPrior(to: first.startDate)!.value.lowerBound
        {
            bolus.notice = .currentGlucoseBelowTarget(glucose: first)
        }

        return bolus
    }

}
