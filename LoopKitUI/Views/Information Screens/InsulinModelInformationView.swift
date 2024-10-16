//
//  InsulinModelInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct InsulinModelInformationView: View {
    var onExit: (() -> Void)?
    var mode: SettingsPresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.appName) private var appName
    
    public init(onExit: (() -> Void)?, mode: SettingsPresentationMode = .acceptanceFlow) {
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(TherapySetting.insulinModel.title),
            informationalContent: {
                VStack (alignment: .leading, spacing: 20) {
                    diaInfo
                    modelPeakInfo
                }
            },
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var diaInfo: Text {
        Text(String(format: LocalizedString("%1$@ assumes that the insulin it has delivered is actively working to lower your glucose for 6 hours. This setting cannot be changed.", comment: "Information about insulin action duration (1: app name)"), appName))
    }
    
    private var modelPeakInfo: some View {
        VStack (alignment: .leading, spacing: 20) {
            Text(String(format: LocalizedString("You can choose how %1$@ measures rapid acting insulin's peak activity according to one of these two insulin models.", comment: "Information about insulin model (1: app name)"), appName))
            HStack(spacing: 10) {
                bulletCircle
                Text(LocalizedString("The rapid-acting adult model assumes peak activity at 75 minutes.", comment: "Information about adult insulin model"))
            }
            HStack(spacing: 10) {
                bulletCircle
                Text(LocalizedString("The rapid-acting child model assumes peak activity at 65 minutes.", comment: "Information about child insulin model"))
            }
        }
    }
    
    private var bulletCircle: some View {
        Image(systemName: "circle.fill")
            .resizable()
            .foregroundColor(.accentColor.opacity(0.5))
            .frame(width: 8, height: 8)
    }
}
