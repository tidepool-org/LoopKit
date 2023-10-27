//
//  LoopAlgorithm.swift
//  Learn
//
//  Created by Pete Schwamb on 6/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public enum AlgorithmError: Error {
    case missingGlucose
    case glucoseTooOld
    case basalTimelineIncomplete
    case missingSuspendThreshold
    case sensitivityTimelineIncomplete
}

public struct LoopAlgorithmEffects {
    public var insulin: [GlucoseEffect]
    public var carbs: [GlucoseEffect]
    public var retrospectiveCorrection: [GlucoseEffect]
    public var momentum: [GlucoseEffect]
    public var insulinCounteraction: [GlucoseEffectVelocity]
}

public struct AlgorithmEffectsOptions: OptionSet {
    public let rawValue: UInt8

    public static let carbs            = AlgorithmEffectsOptions(rawValue: 1 << 0)
    public static let insulin          = AlgorithmEffectsOptions(rawValue: 1 << 1)
    public static let momentum         = AlgorithmEffectsOptions(rawValue: 1 << 2)
    public static let retrospection    = AlgorithmEffectsOptions(rawValue: 1 << 3)

    public static let all: AlgorithmEffectsOptions = [.carbs, .insulin, .momentum, .retrospection]

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

public struct LoopPrediction {
    public var glucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects
    public var activeInsulin: Double
    public var activeCarbs: Double
}

public struct LoopAlgorithm {
    /// Percentage of recommended dose to apply as bolus when using automatic bolus dosing strategy
    static public let defaultBolusPartialApplicationFactor = 0.4

    /// The duration of recommended temp basals
    static public let tempBasalDuration = TimeInterval(minutes: 30)

    /// The amount of time since a given date that input data should be considered valid
    public static let inputDataRecencyInterval = TimeInterval(minutes: 15)

    static let insulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil)

    /// Generates a forecast predicting glucose.
    ///
    /// Returns nil if the normal scheduled basal, or active temporary basal, is sufficient.
    ///
    /// - Parameters:
    ///   - predictionStart: The starting time of the glucose prediction, defaults to the sample time of the latest glucose sample provided.
    ///   - glucoseHistory: History of glucose values: t-10h to t. Must include at least one value.
    ///   - doses: History of insulin doses: t-16h to t
    ///   - carbEntries: History of carb entries: t-10h to t
    ///   - basal: Scheduled basal rate timeline: t-16h to t
    ///   - sensitivity: Insulin sensitivity timeline: t-16h to t (eventually with mid-absorption isf changes, it will be t-10h to t)
    ///   - carbRatio: Carb ratio timeline: t-10h to t+6h
    ///   - algorithmEffectsOptions: Which effects to include when combining effects to generate glucose prediction
    ///   - useIntegralRetrospectiveCorrection: If true, the prediction will use Integral Retrospection. If false, will use traditional Retrospective Correction
    ///   - carbAbsorptionModel: A model conforming to CarbAbsorptionComputable that is used for computing carb absorption over time.
    /// - Returns: A LoopPrediction struct containing the predicted glucose and the computed intermediate effects used to make the prediction

    public static func generatePrediction(
        predictionStart: Date? = nil,
        glucoseHistory: [StoredGlucoseSample],
        doses: [DoseEntry],
        carbEntries: [StoredCarbEntry],
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        carbRatio: [AbsoluteScheduleValue<Double>],
        algorithmEffectsOptions: AlgorithmEffectsOptions = .all,
        useIntegralRetrospectiveCorrection: Bool = false,
        carbAbsorptionModel: CarbAbsorptionComputable = PiecewiseLinearAbsorption()
    ) -> LoopPrediction {

        guard let latestGlucose = glucoseHistory.last else {
            preconditionFailure("Must have at least one historical glucose value to make a prediction")
        }

        let start = predictionStart ?? latestGlucose.startDate

        if let doseStart = doses.first?.startDate {
            assert(!basal.isEmpty, "Missing basal history input.")
            let basalStart = basal.first!.startDate
            precondition(basalStart <= doseStart, "Basal history must cover historic dose range. First dose date: \(doseStart) > \(basalStart)")
        }

        // Overlay basal history on basal doses, splitting doses to get amount delivered relative to basal
        let annotatedDoses = doses.annotated(with: basal)

        let insulinEffects = annotatedDoses.glucoseEffects(
            insulinModelProvider: insulinModelProvider,
            insulinSensitivityHistory: sensitivity,
            from: start.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval).dateFlooredToTimeInterval(GlucoseMath.defaultDelta),
            to: nil)

        let activeInsulin = doses.insulinOnBoard(insulinModelProvider: insulinModelProvider, at: start)

        // ICE
        let insulinCounteractionEffects = glucoseHistory.counteractionEffects(to: insulinEffects)

        // Carb Effects
        let carbStatus = carbEntries.map(
            to: insulinCounteractionEffects,
            carbRatio: carbRatio,
            insulinSensitivity: sensitivity
        )

        let carbEffects = carbStatus.dynamicGlucoseEffects(
            from: start.addingTimeInterval(-IntegralRetrospectiveCorrection.retrospectionInterval),
            carbRatios: carbRatio,
            insulinSensitivities: sensitivity,
            absorptionModel: carbAbsorptionModel
        )

        let activeCarbs = carbStatus.dynamicCarbsOnBoard(at: start, absorptionModel: carbAbsorptionModel)

        // RC
        let retrospectiveGlucoseDiscrepancies = insulinCounteractionEffects.subtracting(carbEffects)
        let retrospectiveGlucoseDiscrepanciesSummed = retrospectiveGlucoseDiscrepancies.combinedSums(of: LoopMath.retrospectiveCorrectionGroupingInterval * 1.01)

        let rc: RetrospectiveCorrection

        if useIntegralRetrospectiveCorrection {
            rc = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        } else {
            rc = StandardRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        }

        let rcEffect = rc.computeEffect(
            startingAt: latestGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
            recencyInterval: TimeInterval(minutes: 15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval
        )

        var effects = [[GlucoseEffect]]()

        if algorithmEffectsOptions.contains(.carbs) {
            effects.append(carbEffects)
        }

        if algorithmEffectsOptions.contains(.insulin) {
            effects.append(insulinEffects)
        }

        if algorithmEffectsOptions.contains(.retrospection) {
            effects.append(rcEffect)
        }

        // Glucose Momentum
        let momentumEffects: [GlucoseEffect]
        if algorithmEffectsOptions.contains(.momentum) {
            let momentumInputData = glucoseHistory.filterDateRange(start.addingTimeInterval(-GlucoseMath.momentumDataInterval), start)
            momentumEffects = momentumInputData.linearMomentumEffect()
        } else {
            momentumEffects = []
        }

        var prediction = LoopMath.predictGlucose(startingAt: latestGlucose, momentum: momentumEffects, effects: effects)

        // Dosing requires prediction entries at least as long as the insulin model duration.
        // If our prediction is shorter than that, then extend it here.
        let finalDate = latestGlucose.startDate.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration)
        if let last = prediction.last, last.startDate < finalDate {
            prediction.append(PredictedGlucoseValue(startDate: finalDate, quantity: last.quantity))
        }

        return LoopPrediction(
            glucose: prediction,
            effects: LoopAlgorithmEffects(
                insulin: insulinEffects,
                carbs: carbEffects,
                retrospectiveCorrection: rcEffect,
                momentum: momentumEffects,
                insulinCounteraction: insulinCounteractionEffects
            ),
            activeInsulin: activeInsulin,
            activeCarbs: activeCarbs
        )
    }

    // Helper to generate prediction with LoopPredictionInput struct
    public static func generatePrediction(input: LoopPredictionInput) -> LoopPrediction {

        return generatePrediction(
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            algorithmEffectsOptions: input.algorithmEffectsOptions,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection,
            carbAbsorptionModel: input.carbAbsorptionModel.model
        )
    }

    // Computes an amount of insulin to correct the given prediction
    public static func insulinCorrection(
        prediction: [PredictedGlucoseValue],
        at deliveryDate: Date,
        target: GlucoseRangeTimeline,
        suspendThreshold: HKQuantity,
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        insulinType: InsulinType
    ) -> InsulinCorrection {
        let insulinModel = insulinModelProvider.model(for: insulinType)

        return prediction.insulinCorrection(
            to: target,
            at: deliveryDate,
            suspendThreshold: suspendThreshold,
            insulinSensitivity: sensitivity,
            model: insulinModel)
    }

    // Computes a 30 minute temp basal dose to correct the given prediction
    public static func recommendTempBasal(
        for correction: InsulinCorrection,
        at deliveryDate: Date,
        neutralBasalRate: Double,
        activeInsulin: Double,
        maxBolus: Double,
        maxBasalRate: Double
    ) -> TempBasalRecommendation? {

        var maxBasalRate = maxBasalRate

        // TODO: Allow `highBasalThreshold` to be a configurable setting
        if case .aboveRange(min: let min, correcting: _, minTarget: let highBasalThreshold, units: _) = correction,
            min.quantity < highBasalThreshold
        {
            maxBasalRate = neutralBasalRate
        }

        // Enforce max IOB, calculated from the user entered maxBolus
        let automaticDosingIOBLimit = maxBolus * 2.0
        let iobHeadroom = automaticDosingIOBLimit - activeInsulin

        let maxThirtyMinuteRateToKeepIOBBelowLimit = iobHeadroom * (TimeInterval.hours(1) / tempBasalDuration) + neutralBasalRate  // 30 minutes of a U/hr rate
        maxBasalRate = Swift.min(maxThirtyMinuteRateToKeepIOBBelowLimit, maxBasalRate)

        return correction.asTempBasal(
            neutralBasalRate: neutralBasalRate,
            maxBasalRate: maxBasalRate,
            duration: tempBasalDuration
        )
    }

    // Computes a bolus or low-temp basal dose to correct the given prediction
    public static func recommendAutomaticDose(
        for correction: InsulinCorrection,
        at deliveryDate: Date,
        applicationFactor: Double,
        neutralBasalRate: Double,
        activeInsulin: Double,
        maxBolus: Double,
        maxBasalRate: Double
    ) -> AutomaticDoseRecommendation? {

        var maxAutomaticBolus = maxBolus * applicationFactor

        if case .aboveRange(min: let min, correcting: _, minTarget: let doseThreshold, units: _) = correction,
            min.quantity < doseThreshold
        {
            maxAutomaticBolus = 0
        }

        let temp: TempBasalRecommendation? = correction.asTempBasal(
            neutralBasalRate: neutralBasalRate,
            maxBasalRate: neutralBasalRate,
            duration: .minutes(30)
        )

        let bolusUnits = correction.asPartialBolus(
            partialApplicationFactor: applicationFactor,
            maxBolusUnits: maxAutomaticBolus
        )

        if temp != nil || bolusUnits > 0 {
            return AutomaticDoseRecommendation(basalAdjustment: temp, bolusUnits: bolusUnits)
        }

        return nil
    }

    // Computes a manual bolus to correct the given prediction
    public static func recommendManualBolus(
        for correction: InsulinCorrection,
        maxBolus: Double,
        currentGlucose: StoredGlucoseSample,
        target: GlucoseRangeTimeline
    ) -> ManualBolusRecommendation {
        var bolus = correction.asManualBolus(maxBolus: maxBolus)

        if let targetAtCurrentGlucose = target.closestPrior(to: currentGlucose.startDate),
           currentGlucose.quantity < targetAtCurrentGlucose.value.lowerBound
        {
            bolus.notice = .currentGlucoseBelowTarget(glucose: currentGlucose)
        }

        return bolus
    }

    public static func recommendDose(input: LoopAlgorithmInput) throws -> LoopAlgorithmDoseRecommendation {
        return try run(input: input).doseRecommendation
    }

    public static func run(input: LoopAlgorithmInput) throws -> LoopAlgorithmOutput {

        guard let latestGlucose = input.glucoseHistory.last else {
            throw AlgorithmError.missingGlucose
        }

        guard input.predictionStart.timeIntervalSince(latestGlucose.startDate) < inputDataRecencyInterval else {
            throw AlgorithmError.glucoseTooOld
        }

        guard let scheduledBasalRate = input.basal.closestPrior(to: input.predictionStart)?.value else {
            throw AlgorithmError.basalTimelineIncomplete
        }

        let forecastEnd = input.predictionStart.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration)

        guard let sensitivityEndDate = input.sensitivity.last?.endDate, sensitivityEndDate >= forecastEnd else {
            throw AlgorithmError.sensitivityTimelineIncomplete
        }

        let prediction = generatePrediction(
            predictionStart: input.predictionStart,
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            carbAbsorptionModel: input.carbAbsorptionModel.model
        )

        guard let suspendThreshold = input.suspendThreshold ?? input.target.closestPrior(to: input.predictionStart)?.value.lowerBound else {
            throw AlgorithmError.missingSuspendThreshold
        }

        // TODO: This is to be removed when implementing mid-absorption ISF changes
        // This sets a single ISF value for the duration of the dose.
        let correctionSensitivity = [input.sensitivity.first { $0.startDate <= input.predictionStart && $0.endDate >= input.predictionStart }!]

        let correction = insulinCorrection(
            prediction: prediction.glucose,
            at: input.predictionStart,
            target: input.target,
            suspendThreshold: suspendThreshold,
            sensitivity: correctionSensitivity,
            insulinType: input.recommendationInsulinType)

        let doseRecommendation: LoopAlgorithmDoseRecommendation

        switch input.recommendationType {
        case .manualBolus:
            let recommendation = recommendManualBolus(
                for: correction,
                maxBolus: input.maxBolus,
                currentGlucose: latestGlucose, 
                target: input.target)
            doseRecommendation = LoopAlgorithmDoseRecommendation(manual: recommendation)
        case .automaticBolus:
            let recommendation = recommendAutomaticDose(
                for: correction,
                at: input.predictionStart,
                applicationFactor: input.automaticBolusApplicationFactor ?? defaultBolusPartialApplicationFactor,
                neutralBasalRate: scheduledBasalRate,
                activeInsulin: prediction.activeInsulin,
                maxBolus: input.maxBolus,
                maxBasalRate: input.maxBasalRate)
            doseRecommendation = LoopAlgorithmDoseRecommendation(automatic: recommendation)
        case .tempBasal:
            let recommendation = recommendTempBasal(
                for: correction,
                at: input.predictionStart,
                neutralBasalRate: scheduledBasalRate,
                activeInsulin: prediction.activeInsulin,
                maxBolus: input.maxBolus,
                maxBasalRate: input.maxBasalRate)
            doseRecommendation = LoopAlgorithmDoseRecommendation(automatic: AutomaticDoseRecommendation(basalAdjustment: recommendation))
        }

        return LoopAlgorithmOutput(
            doseRecommendation: doseRecommendation,
            predictedGlucose: prediction.glucose,
            effects: prediction.effects,
            activeInsulin: prediction.activeInsulin,
            activeCarbs: prediction.activeCarbs
        )
    }
}


