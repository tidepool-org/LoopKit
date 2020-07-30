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
    let appName: String
    
    public init(
        settingsViewModel: TherapySettingsViewModel,
        supportedModels: SupportedInsulinModelSettings,
        appName: String
    ) {
        precondition(settingsViewModel.therapySettings.glucoseUnit != nil)
        precondition(settingsViewModel.therapySettings.insulinModelSettings != nil)
        self.settingsViewModel = settingsViewModel
        self.appName = appName
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            InsulinModelSelection(
                value: settingsViewModel.therapySettings.insulinModelSettings!,
                insulinSensitivitySchedule: settingsViewModel.therapySettings.insulinSensitivitySchedule,
                glucoseUnit: settingsViewModel.therapySettings.glucoseUnit!,
                supportedModelSettings: settingsViewModel.supportedInsulinModelSettings,
                appName: appName,
                mode: .acceptanceFlow // don't wrap the view in a navigation view
            )
            VStack(spacing: 0) {
                Button(action: {
                    self.settingsViewModel.saveInsulinModel(insulinModelSettings: self.settingsViewModel.therapySettings.insulinModelSettings!)
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

