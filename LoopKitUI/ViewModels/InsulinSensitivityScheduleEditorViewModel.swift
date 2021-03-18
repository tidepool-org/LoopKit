//
//  InsulinSensitivityScheduleEditorViewModel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-15.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

struct InsulinSensitivityScheduleEditorViewModel {
    var saveInsulinSensitivitySchedule: (_ insulinSensitivitySchedule: InsulinSensitivitySchedule) -> Void

    let mode: SettingsPresentationMode

    let insulinSensitivitySchedule: InsulinSensitivitySchedule?

    init(therapySettingsViewModel: TherapySettingsViewModel,
         didSave: (() -> Void)? = nil)
    {
        self.mode = therapySettingsViewModel.mode
        self.insulinSensitivitySchedule = therapySettingsViewModel.insulinSensitivitySchedule
        self.saveInsulinSensitivitySchedule = { [weak therapySettingsViewModel] insulinSensitivitySchedule in
            guard let therapySettingsViewModel = therapySettingsViewModel else {
                return
            }

            //TODO need to check and potentially convert back to just glucose units

            if insulinSensitivitySchedule.unit == HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit()) ||
                insulinSensitivitySchedule.unit == HKUnit.millimolesPerLiter.unitDivided(by: .internationalUnit()),
               let updatedInsulinSensitivitySchedule = InsulinSensitivitySchedule(unit: insulinSensitivitySchedule.unit.unitMultiplied(by: .internationalUnit()),
                                                                                  dailyItems: insulinSensitivitySchedule.items,
                                                                                  timeZone: insulinSensitivitySchedule.timeZone)
            {
                therapySettingsViewModel.saveInsulinSensitivitySchedule(insulinSensitivitySchedule: updatedInsulinSensitivitySchedule)
            } else {
                therapySettingsViewModel.saveInsulinSensitivitySchedule(insulinSensitivitySchedule: insulinSensitivitySchedule)
            }
            didSave?()
        }
    }

    func insulinSensitivitySchedule(for sensitivityUnit: HKUnit) -> InsulinSensitivitySchedule? {
        // InsulinSensitivitySchedule stores only the glucose unit. Need to replace the stored units with sensitivity units

        //TODO consider just storing the sensivity unit (why isn't this being done)
        precondition(sensitivityUnit == HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit()) ||
                        sensitivityUnit == HKUnit.millimolesPerLiter.unitDivided(by: .internationalUnit()))

        guard let insulinSensitivitySchedule = insulinSensitivitySchedule else { return nil }

        return InsulinSensitivitySchedule(sensitivityUnit: sensitivityUnit,
                                          dailyItems: insulinSensitivitySchedule.items,
                                          timeZone: insulinSensitivitySchedule.timeZone)
    }
}
