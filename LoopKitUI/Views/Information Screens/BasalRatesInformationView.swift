//
//  BasalRatesInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public struct BasalRatesInformationView: View {
    var onExit: (() -> Void)?
    var mode: PresentationMode
    var preferredUnit: HKUnit = HKUnit.milligramsPerDeciliter

    @Environment(\.presentationMode) var presentationMode
    
    public init(onExit: (() -> Void)?, mode: PresentationMode = .acceptanceFlow) {
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(TherapySetting.basalRate.title),
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
            Text(LocalizedString("Your basal rate of insulin is the number of units per hour that you want to use to cover your background insulin needs.", comment: "Information about basal rates"))
            Text(LocalizedString("Loop supports 1 to 48 rates per day.", comment: "Information about max number of basal rates"))
            Text(LocalizedString("The schedule starts at midnight and cannot contain a rate of 0 U/hr.", comment: "Information about basal rate scheduling"))
        }
        .foregroundColor(.secondary)
    }
    
    private var illustrationImageName: String {
        switch preferredUnit {
        case .milligramsPerDeciliter:
            return "Correction Range mgdL"
        case .millimolesPerLiter:
            return "Correction Range mmolL"
        default:
            fatalError()
        }
    }

}

struct BasalRatesInformationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BasalRatesInformationView(onExit: nil, mode: .acceptanceFlow)
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light")
        }
        NavigationView {
            BasalRatesInformationView(onExit: nil, mode: .acceptanceFlow)
            .preferredColorScheme(.dark)
            .colorScheme(.dark)
            .previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
            .previewDisplayName("11 Pro dark")
        }
    }
}
