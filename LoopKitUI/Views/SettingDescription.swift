//
//  SettingDescription.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public enum LoopSetting: Int {
    case glucoseTargetRange
    case correctionRangeOverrides
    case suspendThreshold
    case basalRate
    case deliveryLimits
    case insulinModel
    case carbRatio
    case insulinSensitivity
}

public struct SettingDescription: View {
    var text: Text
    var settingType: LoopSetting
    @State var displayHelpPage: Bool = false

    public init(text: Text,
                settingType: LoopSetting = .glucoseTargetRange) {
        self.text = text
        self.settingType = settingType
    }

    public var body: some View {
        HStack(spacing: 8) {
            text
                .font(.callout)
                .foregroundColor(Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            
            infoButton
            .sheet(isPresented: $displayHelpPage) {
                NavigationView {
                    self.helpScreen()
                }
            }
        }
    }
    
    private var infoButton: some View {
        Button(
            action: {
                self.displayHelpPage = true
            },
            label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 25))
                    .foregroundColor(.accentColor)
            }
        )
        .padding(.trailing, 4)
    }

    private func helpScreen() -> some View {
        switch settingType {
        case .glucoseTargetRange:                       
            return AnyView(CorrectionRangeInformationView(exitPage: { self.displayHelpPage = false }, mode: .modal))
        case .correctionRangeOverrides:
            return AnyView(CorrectionRangeOverrideInformationView(exitPage: { self.displayHelpPage = false }, mode: .modal))
        // ANNA TODO: add more once other instructional screens are created
        default:
            return AnyView(CorrectionRangeInformationView(exitPage: { self.displayHelpPage = false }, mode: .modal))
        }
    }
}

struct SettingDescription_Previews: PreviewProvider {
    static var previews: some View {
        SettingDescription(text: Text(verbatim: "When your glucose is predicted to go below this value, the app will recommend a basal rate of 0 U and will not recommend a bolus."), settingType: .glucoseTargetRange)
            .padding(.horizontal)
    }
}
