//
//  TherapySettingsViewModel.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import HealthKit
import LocalAuthentication
import LoopKit
import SwiftUI

public class TherapySettingsViewModel: ObservableObject {
    public typealias SaveCompletion = (TherapySetting, TherapySettings) -> Void
    
    public let mode: PresentationMode
    
    @Published public var therapySettings: TherapySettings
    public var supportedInsulinModelSettings: SupportedInsulinModelSettings
    private let didSave: SaveCompletion?

    private let initialTherapySettings: TherapySettings
    let pumpSupportedIncrements: PumpSupportedIncrements?
    let syncPumpSchedule: PumpManager.SyncSchedule?
    let sensitivityOverridesEnabled: Bool
    let prescription: Prescription?
    let appName: String
    let authenticationChallengeDescription: String

    lazy private var cancellables = Set<AnyCancellable>()

    public init(mode: PresentationMode,
                therapySettings: TherapySettings,
                appName: String,
                supportedInsulinModelSettings: SupportedInsulinModelSettings = SupportedInsulinModelSettings(fiaspModelEnabled: true, walshModelEnabled: true),
                pumpSupportedIncrements: PumpSupportedIncrements? = nil,
                syncPumpSchedule: PumpManager.SyncSchedule? = nil,
                sensitivityOverridesEnabled: Bool = false,
                prescription: Prescription? = nil,
                authenticationChallengeDescription: String = "Authenticate to change setting",
                didSave: SaveCompletion? = nil) {
        self.mode = mode
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.pumpSupportedIncrements = pumpSupportedIncrements
        self.syncPumpSchedule = syncPumpSchedule
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.prescription = prescription
        self.supportedInsulinModelSettings = supportedInsulinModelSettings
        self.appName = appName
        self.authenticationChallengeDescription = authenticationChallengeDescription
        self.didSave = didSave
    }
    
    var insulinModelSelectionViewModel: InsulinModelSelectionViewModel {
        let result = InsulinModelSelectionViewModel(
            insulinModelSettings: therapySettings.insulinModelSettings!,
            insulinSensitivitySchedule: therapySettings.insulinSensitivitySchedule!)
        result.$insulinModelSettings
            .dropFirst() // This is needed to avoid reading the initial value, which starts off an infinite loop
            .sink {
            [weak self] in self?.saveInsulinModel(insulinModelSettings: $0)
        }.store(in: &cancellables)
        return result
    }
    
    /// Reset to initial
    public func reset() {
        therapySettings = initialTherapySettings
    }
    
    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
        beginSaving(TherapySetting.glucoseTargetRange)
    }
    
    public func saveCorrectionRangeOverrides(overrides: CorrectionRangeOverrides, unit: HKUnit) {
        therapySettings.preMealTargetRange = overrides.preMeal?.doubleRange(for: unit)
        therapySettings.workoutTargetRange = overrides.workout?.doubleRange(for: unit)
        beginSaving(TherapySetting.correctionRangeOverrides)
    }
    
    public func saveSuspendThreshold(value: GlucoseThreshold) {
        therapySettings.suspendThreshold = value
        beginSaving(TherapySetting.suspendThreshold)
    }
    
    public func saveBasalRates(basalRates: BasalRateSchedule) {
        therapySettings.basalRateSchedule = basalRates
        beginSaving(TherapySetting.basalRate)
    }
    
    public func saveDeliveryLimits(limits: DeliveryLimits) {
        therapySettings.maximumBasalRatePerHour = limits.maximumBasalRate?.doubleValue(for: .internationalUnitsPerHour)
        therapySettings.maximumBolus = limits.maximumBolus?.doubleValue(for: .internationalUnit())
        beginSaving(TherapySetting.deliveryLimits)
    }
    
    public func saveInsulinModel(insulinModelSettings: InsulinModelSettings) {
        therapySettings.insulinModelSettings = insulinModelSettings
        beginSaving(TherapySetting.insulinModel)
    }
    
    public func saveCarbRatioSchedule(carbRatioSchedule: CarbRatioSchedule) {
        therapySettings.carbRatioSchedule = carbRatioSchedule
        beginSaving(TherapySetting.carbRatio)
    }
    
    public func saveInsulinSensitivitySchedule(insulinSensitivitySchedule: InsulinSensitivitySchedule) {
        therapySettings.insulinSensitivitySchedule = insulinSensitivitySchedule
        beginSaving(TherapySetting.insulinSensitivity)
    }
    
    private func beginSaving(_ setting: TherapySetting) {
        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                   localizedReason: authenticationChallengeDescription,
                                   reply: { (success, error) in
                                    if success {
                                        DispatchQueue.main.async {
                                            self.continueSaving(setting)
                                        }
                                    }
            })
        } else {
            self.continueSaving(setting)
        }
    }
    
    private func continueSaving(_ setting: TherapySetting) {
        didSave?(setting, therapySettings)
    }
}
