//
//  SuspendThresholdEditorViewModel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-01.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

struct SuspendThresholdEditorViewModel {
    var suspendThreshold: HKQuantity?

    let glucoseTargetRangeSchedule: GlucoseRangeSchedule?

    var maxSuspendThresholdValue: HKQuantity

    let mode: SettingsPresentationMode

    var saveSuspendThreshold: (_ suspendThreshold: HKQuantity) -> Void

    let guardrail = Guardrail.suspendThreshold

    public init(therapySettingsViewModel: TherapySettingsViewModel,
                didSave: (() -> Void)? = nil)
    {
        self.suspendThreshold = therapySettingsViewModel.suspendThreshold?.quantity
        self.glucoseTargetRangeSchedule = therapySettingsViewModel.therapySettings.glucoseTargetRangeSchedule

        let preMealTargetRange = therapySettingsViewModel.therapySettings.preMealTargetRange
        let workoutTargetRange = therapySettingsViewModel.therapySettings.workoutTargetRange
        self.maxSuspendThresholdValue = Guardrail.maxSuspendThresholdValue(
            correctionRangeSchedule: glucoseTargetRangeSchedule,
            preMealTargetRange: preMealTargetRange?.quantityRange(for: therapySettingsViewModel.therapySettingsGlucoseUnit),
            workoutTargetRange: workoutTargetRange?.quantityRange(for: therapySettingsViewModel.therapySettingsGlucoseUnit))
        
        self.mode = therapySettingsViewModel.mode
        self.saveSuspendThreshold = { [weak therapySettingsViewModel] newValue in
            guard let therapySettingsViewModel = therapySettingsViewModel else {
                return
            }
            therapySettingsViewModel.saveSuspendThreshold(quantity: newValue)
            didSave?()
        }
    }
}
