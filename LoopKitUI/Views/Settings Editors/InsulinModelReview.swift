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
    let appName: String
    
    public init(
        settingsViewModel: TherapySettingsViewModel,
        supportedModels: SupportedInsulinModelSettings,
        appName: String
    ) {
        precondition(settingsViewModel.therapySettings.glucoseUnit != nil)
        self.settingsViewModel = settingsViewModel
        self.supportedModels = supportedModels
        self.appName = appName
        
        let insulinModel = InsulinModelSettings(from: settingsViewModel.therapySettings.insulinModel!)
        self.insulinSelectionViewModel = InsulinModelSelectionViewModel(
            insulinModelSettings: insulinModel,
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
                    appName: appName,
                    mode: .acceptanceFlow // don't wrap the view in a navigation view
                )
            }
            VStack {
                Button(action: {
                    self.settingsViewModel.saveInsulinModel(insulinModel: self.insulinSelectionViewModel.insulinModelSettings)
                }) {
                    Text(PresentationMode.acceptanceFlow.buttonText)
                    .actionButtonStyle(.primary)
                    .padding()
                }
            }
            // Styling to mimic the floating button of a ConfigurationPage
            .padding(.bottom)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

