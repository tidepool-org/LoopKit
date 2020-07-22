//
//  BasalRatesReview.swift
//  TidepoolServiceKitUI
//
//  Created by Anna Quinlan on 7/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

public struct BasalRatesReview: View {
    @ObservedObject var viewModel: TherapySettingsViewModel
    private let mode: PresentationMode
    
    public init(mode: PresentationMode = .acceptanceFlow, viewModel: TherapySettingsViewModel) {
        precondition(viewModel.therapySettings.glucoseUnit != nil)
        self.viewModel = viewModel
        self.mode = mode
    }
    
    @ViewBuilder public var body: some View {
        if viewModel.pumpSupportedIncrements != nil {
            BasalRateScheduleEditor(
                schedule: viewModel.therapySettings.basalRateSchedule,
                supportedBasalRates: viewModel.pumpSupportedIncrements!.basalRates ,
                maximumBasalRate: viewModel.therapySettings.maximumBasalRatePerHour,
                maximumScheduleEntryCount: viewModel.pumpSupportedIncrements!.maximumBasalScheduleEntryCount,
                syncSchedule: viewModel.pumpSyncSchedule,
                onSave: { newRates in
                    self.viewModel.saveBasalRates(basalRates: newRates)
                },
                mode: mode
            )
        } else {
            Text("No Pump")
        }
    }
}
