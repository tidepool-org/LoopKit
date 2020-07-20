//
//  TherapySettingsViewModel.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import HealthKit

public class TherapySettingsViewModel: ObservableObject {
    // Note: duplicated from InsulinModelSelection
    public struct SupportedModelSettings {
        var fiaspModelEnabled: Bool
        var walshModelEnabled: Bool
        public init(fiaspModelEnabled: Bool, walshModelEnabled: Bool) {
            self.fiaspModelEnabled = fiaspModelEnabled
            self.walshModelEnabled = walshModelEnabled
        }
    }

    private let initialTherapySettings: TherapySettings
    @Published public var therapySettings: TherapySettings
    public var supportedModelSettings: SupportedModelSettings
    public var didFinishStep: (() -> Void)?
    let pumpSupportedIncrements: PumpSupportedIncrements?

    public init(therapySettings: TherapySettings,
                supportedModelSettings: SupportedModelSettings = SupportedModelSettings(fiaspModelEnabled: true, walshModelEnabled: true),
                pumpSupportedIncrements: PumpSupportedIncrements? = nil) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.pumpSupportedIncrements = pumpSupportedIncrements
        self.supportedModelSettings = supportedModelSettings
    }
    
    /// Reset to initial
    public func reset() {
        therapySettings = initialTherapySettings
    }
    
    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
    }
    
    public func saveCorrectionRangeOverrides(overrides: CorrectionRangeOverrides, unit: HKUnit) {
        therapySettings.preMealTargetRange = overrides.preMeal?.doubleRange(for: unit)
        therapySettings.workoutTargetRange = overrides.workout?.doubleRange(for: unit)
    }
    
    public func saveSuspendThreshold(value: GlucoseThreshold) {
        therapySettings.suspendThreshold = value
    }
    
    public func saveBasalRates(basalRates: BasalRateSchedule) {
        therapySettings.basalRateSchedule = basalRates
    }
    
    public func saveDeliveryLimits(limits: DeliveryLimits) {
        therapySettings.maximumBasalRatePerHour = limits.maximumBasalRate?.doubleValue(for: .internationalUnitsPerHour)
        therapySettings.maximumBolus = limits.maximumBolus?.doubleValue(for: .internationalUnit())
    }
}
