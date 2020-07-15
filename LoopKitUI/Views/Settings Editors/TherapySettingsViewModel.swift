//
//  TherapySettingsViewModel.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

public class TherapySettingsViewModel: ObservableObject {
    private var initialTherapySettings: TherapySettings
    var therapySettings: TherapySettings
    let supportedBasalRates: [Double]?

    public init(therapySettings: TherapySettings, supportedBasalRates: [Double]?) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.supportedBasalRates = supportedBasalRates
    }
    
    /// Reset to original
    func reset() {
        therapySettings = initialTherapySettings
    }
}
