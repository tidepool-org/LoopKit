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
    let mode: PresentationMode
    var onSave: ((InsulinModelSettings) -> Void)?
    
    public init(
        settingsViewModel: TherapySettingsViewModel,
        supportedModels: SupportedInsulinModelSettings,
        appName: String,
        mode: PresentationMode = .acceptanceFlow, // don't wrap the view in a navigation view
        onSave: ((InsulinModelSettings) -> Void)? = nil
    ) {
        precondition(settingsViewModel.therapySettings.glucoseUnit != nil)
        precondition(settingsViewModel.therapySettings.insulinModelSettings != nil)
        self.settingsViewModel = settingsViewModel
        self.supportedModels = supportedModels
        self.appName = appName
        self.mode = mode
        self.onSave = onSave

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
                    appName: appName,
                    mode: mode
                )
            }
            VStack {
                Button(action: {
                    self.settingsViewModel.saveInsulinModel(insulinModelSettings: self.insulinSelectionViewModel.insulinModelSettings)
                    self.onSave?(self.insulinSelectionViewModel.insulinModelSettings)
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

