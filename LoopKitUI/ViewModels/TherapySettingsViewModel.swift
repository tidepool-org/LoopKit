//
//  TherapySettingsViewModel.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import LoopKit
import HealthKit
import SwiftUI

public class TherapySettingsViewModel: ObservableObject {
    public typealias SaveCompletion = (TherapySetting, TherapySettings) -> Void
   
    /// This method type describes a way to "precheck" before saving max temp basal.  The host app is going to supply a closure for this, and based on the
    /// response, either proceed with saving max temp, or display an error.
    ///
    /// - Parameters:
    ///   - unitsPerHour: The temporary basal rate proposed to validate, in international units per hour
    ///   - completion: A closure called after the command is complete
    ///   - error: An optional error describing why the command failed
    public typealias MaxTempBasalSavePreflight = (_ unitsPerHour: Double, _ completion: @escaping (_ error: Error?) -> Void) -> Void
    
    public typealias SyncBasalRateSchedule = (_ items: [RepeatingScheduleValue<Double>], _ completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) -> Void

    public typealias SyncDeliveryLimits = (_ deliveryLimits: DeliveryLimits, _ completion: @escaping (_ result: Swift.Result<DeliveryLimits, Error>) -> Void) -> Void


    @Published public var therapySettings: TherapySettings
    private let didSave: SaveCompletion?

    private let initialTherapySettings: TherapySettings
    let pumpSupportedIncrements: (() -> PumpSupportedIncrements?)?
    let syncBasalRateSchedule: SyncBasalRateSchedule?
    let syncDeliveryLimits: SyncDeliveryLimits?
    let maxTempBasalSavePreflight: MaxTempBasalSavePreflight?
    let sensitivityOverridesEnabled: Bool
    public var prescription: Prescription?

    public init(therapySettings: TherapySettings,
                pumpSupportedIncrements: (() -> PumpSupportedIncrements?)? = nil,
                syncBasalRateSchedule: SyncBasalRateSchedule? = nil,
                syncDeliveryLimits: SyncDeliveryLimits? = nil,
                maxTempBasalSavePreflight: MaxTempBasalSavePreflight? = nil,
                sensitivityOverridesEnabled: Bool = false,
                prescription: Prescription? = nil,
                didSave: SaveCompletion? = nil) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.pumpSupportedIncrements = pumpSupportedIncrements
        self.syncBasalRateSchedule = syncBasalRateSchedule
        self.syncDeliveryLimits = syncDeliveryLimits
        self.maxTempBasalSavePreflight = maxTempBasalSavePreflight
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.prescription = prescription
        self.didSave = didSave
    }

    var deliveryLimits: DeliveryLimits {
        return DeliveryLimits(maximumBasalRate: therapySettings.maximumBasalRatePerHour.map { HKQuantity(unit: .internationalUnitsPerHour, doubleValue: $0) },
                              maximumBolus: therapySettings.maximumBolus.map { HKQuantity(unit: .internationalUnit(), doubleValue: $0) } )
    }

    var suspendThreshold: GlucoseThreshold? {
        return therapySettings.suspendThreshold
    }

    var glucoseTargetRangeSchedule: GlucoseRangeSchedule? {
        return therapySettings.glucoseTargetRangeSchedule
    }

    func glucoseTargetRangeSchedule(for glucoseUnit: HKUnit) -> GlucoseRangeSchedule? {
        return glucoseTargetRangeSchedule?.schedule(for: glucoseUnit)
    }

    var correctionRangeOverrides: CorrectionRangeOverrides {
        return CorrectionRangeOverrides(preMeal: therapySettings.correctionRangeOverrides?.preMeal,
                                        workout: therapySettings.correctionRangeOverrides?.workout)
    }

    var correctionRangeScheduleRange: ClosedRange<HKQuantity> {
        precondition(therapySettings.glucoseTargetRangeSchedule != nil)
        return therapySettings.glucoseTargetRangeSchedule!.scheduleRange()
    }

    var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        return therapySettings.insulinSensitivitySchedule
    }

    func insulinSensitivitySchedule(for glucoseUnit: HKUnit) -> InsulinSensitivitySchedule? {
        return insulinSensitivitySchedule?.schedule(for: glucoseUnit)
    }

    /// Reset to initial
    public func reset() {
        therapySettings = initialTherapySettings
    }

    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
        didSave?(TherapySetting.glucoseTargetRange, therapySettings)
    }
        
    public func saveCorrectionRangeOverride(preset: CorrectionRangeOverrides.Preset,
                                            correctionRangeOverrides: CorrectionRangeOverrides) {
        therapySettings.correctionRangeOverrides = correctionRangeOverrides
        switch preset {
        case .preMeal:
            didSave?(TherapySetting.preMealCorrectionRangeOverride, therapySettings)
        case .workout:
            didSave?(TherapySetting.workoutCorrectionRangeOverride, therapySettings)
        }
    }

    public func saveSuspendThreshold(quantity: HKQuantity, withDisplayGlucoseUnit displayGlucoseUnit: HKUnit) {
        therapySettings.suspendThreshold = GlucoseThreshold(unit: displayGlucoseUnit, value: quantity.doubleValue(for: displayGlucoseUnit))
        didSave?(TherapySetting.suspendThreshold, therapySettings)
    }
    
    public func saveBasalRates(basalRates: BasalRateSchedule) {
        therapySettings.basalRateSchedule = basalRates
        didSave?(TherapySetting.basalRate, therapySettings)
    }
    
    public func saveDeliveryLimits(limits: DeliveryLimits) {
        therapySettings.maximumBasalRatePerHour = limits.maximumBasalRate?.doubleValue(for: .internationalUnitsPerHour)
        therapySettings.maximumBolus = limits.maximumBolus?.doubleValue(for: .internationalUnit())
        didSave?(TherapySetting.deliveryLimits, therapySettings)
    }
    
    public func saveInsulinModel(insulinModelPreset: ExponentialInsulinModelPreset) {
        therapySettings.defaultRapidActingModel = insulinModelPreset
        didSave?(TherapySetting.insulinModel, therapySettings)
    }
    
    public func saveCarbRatioSchedule(carbRatioSchedule: CarbRatioSchedule) {
        therapySettings.carbRatioSchedule = carbRatioSchedule
        didSave?(TherapySetting.carbRatio, therapySettings)
    }
    
    public func saveInsulinSensitivitySchedule(insulinSensitivitySchedule: InsulinSensitivitySchedule) {
        therapySettings.insulinSensitivitySchedule = insulinSensitivitySchedule
        didSave?(TherapySetting.insulinSensitivity, therapySettings)
    }
}
