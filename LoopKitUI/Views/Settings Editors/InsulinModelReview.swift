//
//  InsulinModelReview.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import SwiftUI
import LoopKit

public struct InsulinModelReview: View {
    @ObservedObject var settingsViewModel: TherapySettingsViewModel
    var insulinSelectionViewModel: InsulinModelSelectionViewModel
    var supportedModels: SupportedInsulinModelSettings
    
    public init(
        settingsViewModel: TherapySettingsViewModel,
        supportedModels: SupportedInsulinModelSettings
    ) {
        precondition(settingsViewModel.therapySettings.glucoseUnit != nil)
        precondition(settingsViewModel.therapySettings.insulinModelSettings != nil)
        self.settingsViewModel = settingsViewModel
        self.supportedModels = supportedModels

        self.insulinSelectionViewModel = InsulinModelSelectionViewModel(
            insulinModelSettings: settingsViewModel.therapySettings.insulinModelSettings!,
            insulinSensitivitySchedule: settingsViewModel.therapySettings.insulinSensitivitySchedule
        )
    }
    
    public var body: some View {
        VStack {
            VStack {
                InsulinModelSelection(
                    viewModel: insulinSelectionViewModel,
                    glucoseUnit: settingsViewModel.therapySettings.glucoseUnit!,
                    supportedModelSettings: supportedModels,
                    mode: .acceptanceFlow // don't wrap the view in a navigation view
                )
            }
            VStack {
                Button(action: {
                    self.settingsViewModel.saveInsulinModel(insulinModelSettings: self.insulinSelectionViewModel.insulinModelSettings)
                }) {
                    Text(PresentationMode.acceptanceFlow.buttonText)
                    .actionButtonStyle(.primary)
                    .padding()
                }
            }
            // Styling to mimic the floating button of a ConfigurationPage
            .padding(.bottom)
            .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

