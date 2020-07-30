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
    @ObservedObject var viewModel: TherapySettingsViewModel
    let appName: String
    
    public init(
        settingsViewModel: TherapySettingsViewModel,
        supportedModels: SupportedInsulinModelSettings,
        appName: String
    ) {
        precondition(settingsViewModel.therapySettings.glucoseUnit != nil)
        precondition(settingsViewModel.therapySettings.insulinModelSettings != nil)
        self.viewModel = settingsViewModel
        self.appName = appName
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            InsulinModelSelection(
                value: viewModel.therapySettings.insulinModelSettings!,
                insulinSensitivitySchedule: viewModel.therapySettings.insulinSensitivitySchedule,
                glucoseUnit: viewModel.therapySettings.glucoseUnit!,
                supportedModelSettings: viewModel.supportedInsulinModelSettings,
                appName: appName,
                mode: .acceptanceFlow, // don't wrap the view in a navigation view
                onSave: {
                    self.viewModel.saveInsulinModel(insulinModelSettings: $0)
                }
            )
            VStack(spacing: 0) {
                Button(action: {
                    self.viewModel.saveInsulinModel(insulinModelSettings: self.viewModel.therapySettings.insulinModelSettings!)
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

