//
//  TherapySettings.swift
//  LoopKit
//
//  Created by Anna Quinlan on 7/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit

public enum BGUnit: String, Codable {
    case mgdl
    case mmol
    
    public var hkUnit: HKUnit {
        switch self {
        case .mgdl:
            return .milligramsPerDeciliter
        case .mmol:
            return .millimolesPerLiter
        }
    }
}

public struct TherapySettings: Equatable, Codable {
    
    public var glucoseTargetRangeSchedule: GlucoseRangeSchedule?

    public var preMealTargetRange: DoubleRange?

    public var workoutTargetRange: DoubleRange?

    public var maximumBasalRatePerHour: Double?

    public var maximumBolus: Double?

    public var suspendThreshold: GlucoseThreshold?
    
    public var insulinSensitivitySchedule: InsulinSensitivitySchedule?
    
    public var carbRatioSchedule: CarbRatioSchedule?
    
    public var basalRateSchedule: BasalRateSchedule?
    
    public var insulinModel: StoredSettings.InsulinModel?
    
    public var glucoseUnit: BGUnit?
    
    // ANNA TODO: see if can get rid of nils
    public init(
        glucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
        preMealTargetRange: DoubleRange? = nil,
        workoutTargetRange: DoubleRange? = nil,
        maximumBasalRatePerHour: Double? = nil,
        maximumBolus: Double? = nil,
        suspendThreshold: GlucoseThreshold? = nil,
        insulinSensitivitySchedule: InsulinSensitivitySchedule? = nil,
        carbRatioSchedule: CarbRatioSchedule? = nil,
        basalRateSchedule: BasalRateSchedule? = nil,
        insulinModel: StoredSettings.InsulinModel? = nil,
        glucoseUnit: BGUnit? = nil
    ){
        self.glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        self.preMealTargetRange = preMealTargetRange
        self.workoutTargetRange = workoutTargetRange
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.maximumBolus = maximumBolus
        self.suspendThreshold = suspendThreshold
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
        self.carbRatioSchedule = carbRatioSchedule
        self.basalRateSchedule = basalRateSchedule
        self.insulinModel = insulinModel
        self.glucoseUnit = glucoseUnit
    }
}
