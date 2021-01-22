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
    
    public let mode: SettingsPresentationMode
    
    @Published public var therapySettings: TherapySettings
    public var supportedInsulinModelSettings: SupportedInsulinModelSettings
    private let didSave: SaveCompletion?

    private let initialTherapySettings: TherapySettings
    let pumpSupportedIncrements: (() -> PumpSupportedIncrements?)?
    let syncPumpSchedule: (() -> PumpManager.SyncSchedule?)?
    let sensitivityOverridesEnabled: Bool
    public var prescription: Prescription?
    
    @Published public var preferredGlucoseUnit: HKUnit

    lazy private var cancellables = Set<AnyCancellable>()
    
    public let chartColors: ChartColorPalette

    public init(mode: SettingsPresentationMode,
                therapySettings: TherapySettings,
                preferredGlucoseUnit: HKUnit,
                supportedInsulinModelSettings: SupportedInsulinModelSettings = SupportedInsulinModelSettings(fiaspModelEnabled: true, walshModelEnabled: true),
                pumpSupportedIncrements: (() -> PumpSupportedIncrements?)? = nil,
                syncPumpSchedule: (() -> PumpManager.SyncSchedule?)? = nil,
                sensitivityOverridesEnabled: Bool = false,
                prescription: Prescription? = nil,
                chartColors: ChartColorPalette,
                didSave: SaveCompletion? = nil) {
        self.mode = mode
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.preferredGlucoseUnit = preferredGlucoseUnit
        self.pumpSupportedIncrements = pumpSupportedIncrements
        self.syncPumpSchedule = syncPumpSchedule
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.prescription = prescription
        self.supportedInsulinModelSettings = supportedInsulinModelSettings
        self.chartColors = chartColors
        self.didSave = didSave
    }

    var deliveryLimits: DeliveryLimits {
        return DeliveryLimits(maximumBasalRate: therapySettings.maximumBasalRatePerHour.map { HKQuantity(unit: .internationalUnitsPerHour, doubleValue: $0) },
                              maximumBolus: therapySettings.maximumBolus.map { HKQuantity(unit: .internationalUnit(), doubleValue: $0) } )
    }

    var suspendThreshold: GlucoseThreshold? {
        return therapySettings.suspendThreshold
    }

    /// Reset to initial
    public func reset() {
        therapySettings = initialTherapySettings
    }

    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
        didSave?(TherapySetting.glucoseTargetRange, therapySettings)
    }
        
    public func saveCorrectionRangeOverride(preMeal: ClosedRange<HKQuantity>?, unit: HKUnit) {
        therapySettings.preMealTargetRange = preMeal?.doubleRange(for: unit)
        didSave?(TherapySetting.preMealCorrectionRangeOverride, therapySettings)
    }
    
    public func saveCorrectionRangeOverride(workout: ClosedRange<HKQuantity>?, unit: HKUnit) {
        therapySettings.workoutTargetRange = workout?.doubleRange(for: unit)
        didSave?(TherapySetting.workoutCorrectionRangeOverride, therapySettings)
    }

    public func saveSuspendThreshold(quantity: HKQuantity) {
        let settingsGlucoseUnit = therapySettings.glucoseUnit ?? preferredGlucoseUnit
        therapySettings.suspendThreshold = GlucoseThreshold(unit: settingsGlucoseUnit, value: quantity.doubleValue(for: settingsGlucoseUnit))
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
    
    public func saveInsulinModel(insulinModelSettings: InsulinModelSettings) {
        therapySettings.insulinModelSettings = insulinModelSettings
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

// MARK: Navigation

extension TherapySettingsViewModel {

    func screen(for setting: TherapySetting) -> (_ goBack: @escaping () -> Void) -> AnyView {
        switch setting {
        case .suspendThreshold:
            return { goBack in
                AnyView(SuspendThresholdEditor(viewModel: self, didSave: goBack).environment(\.dismiss, goBack))
            }
        case .glucoseTargetRange:
            return { goBack in
                AnyView(CorrectionRangeScheduleEditor(viewModel: self, didSave: goBack).environment(\.dismiss, goBack))
            }
        case .preMealCorrectionRangeOverride:
            return { goBack in
                AnyView(CorrectionRangeOverridesEditor(viewModel: self, preset: .preMeal, didSave: goBack).environment(\.dismiss, goBack))
            }
        case .workoutCorrectionRangeOverride:
            return { goBack in
                AnyView(CorrectionRangeOverridesEditor(viewModel: self, preset: .workout, didSave: goBack).environment(\.dismiss, goBack))
            }
        case .basalRate:
            if self.pumpSupportedIncrements?() != nil {
                return { goBack in
                    AnyView(BasalRateScheduleEditor(viewModel: self, didSave: goBack).environment(\.dismiss, goBack))
                }
            }
        case .deliveryLimits:
            if self.pumpSupportedIncrements?() != nil {
                return { goBack in
                    AnyView(DeliveryLimitsEditor(viewModel: self, didSave: goBack).environment(\.dismiss, goBack))
                }
            }
        case .insulinModel:
            if self.therapySettings.insulinModelSettings != nil {
                return { goBack in
                    AnyView(InsulinModelSelection(viewModel: self, didSave: goBack).environment(\.dismiss, goBack))
                }
            }
        case .carbRatio:
            return { goBack in
                AnyView(CarbRatioScheduleEditor(viewModel: self, didSave: goBack).environment(\.dismiss, goBack))
            }
        case .insulinSensitivity:
            return { goBack in
                return AnyView(InsulinSensitivityScheduleEditor(viewModel: self, didSave: goBack).environment(\.dismiss, goBack))
            }
        case .none:
            break
        }
        return { _ in AnyView(Text("\(setting.title)")) }
    }
}
