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
    var text: AnyView!
    let onExit: (() -> Void)?
    let mode: PresentationMode
    let therapySetting: TherapySetting
    let preferredUnit: HKUnit
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(
        therapySetting: TherapySetting,
        preferredUnit: HKUnit? = nil,
        text: AnyView? = nil,
        onExit: (() -> Void)?,
        mode: PresentationMode = .acceptanceFlow
    ){
        self.therapySetting = therapySetting
        self.preferredUnit = preferredUnit ?? .milligramsPerDeciliter
        self.onExit = onExit
        self.mode = mode
        self.text = text ?? AnyView(defaultText)
    }
    
    public var body: some View {
        InformationView(
            title: Text(self.therapySetting.title),
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
    
    private var defaultText: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(therapySetting.descriptiveText)
        }
        .accentColor(.secondary)
        .foregroundColor(.accentColor)
    }
    
    private var illustrationImageName: String {
        return "\(therapySetting.title) \(preferredUnit.description.replacingOccurrences(of: "/", with: ""))"
    }
}