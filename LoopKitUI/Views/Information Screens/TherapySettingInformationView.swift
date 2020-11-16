//
//  GlucoseTherapySettingInformationView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 11/16/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public struct GlucoseTherapySettingInformationView: View {
    var onExit: (() -> Void)?
    var mode: PresentationMode
    var preferredUnit: HKUnit
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(
        therapySetting: TherapySetting,
        preferredUnit: HKUnit? = nil,
        onExit: (() -> Void)?,
        mode: PresentationMode = .acceptanceFlow
    ){
        self.preferredUnit = preferredUnit ?? .milligramsPerDeciliter
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(TherapySetting.suspendThreshold.title),
            informationalContent: {
                VStack {
                    illustration
                    text
                }
            },
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var illustration: some View {
        Image(frameworkImage: illustrationImageName)
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: ContentMode.fit)
    }
    
    private var text: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(TherapySetting.suspendThreshold.descriptiveText)
        }
        .accentColor(.secondary)
        .foregroundColor(.accentColor)
    }
    
    private var illustrationImageName: String {
        switch preferredUnit {
        case .milligramsPerDeciliter:
            return "Glucose Safety Limit mgdL"
        case .millimolesPerLiter:
            return "Glucose Safety Limit mmolL"
        default:
            fatalError()
        }
    }
}

struct SuspendThresholdInformationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SuspendThresholdInformationView(onExit: nil, mode: .acceptanceFlow)
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light")
        }
        NavigationView {
            SuspendThresholdInformationView(onExit: nil, mode: .acceptanceFlow)
            .preferredColorScheme(.dark)
            .colorScheme(.dark)
            .previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
            .previewDisplayName("11 Pro dark")
        }
    }
}
