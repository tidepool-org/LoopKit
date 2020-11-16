//
//  SuspendThresholdInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public struct SuspendThresholdInformationView: View {
    var onExit: (() -> Void)?
    var mode: PresentationMode
    var preferredUnit: HKUnit = HKUnit.milligramsPerDeciliter
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(
        onExit: (() -> Void)?,
        mode: PresentationMode = .acceptanceFlow
    ){
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        GlucoseTherapySettingInformationView(therapySetting: .suspendThreshold,
                                             preferredUnit: preferredUnit,
                                             onExit: onExit,
                                             mode: mode)
    }
}

struct SuspendThresholdInformationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SuspendThresholdInformationView(onExit: nil, mode: .acceptanceFlow)
        }
        .colorScheme(.light)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
        .previewDisplayName("SE light")
        NavigationView {
            SuspendThresholdInformationView(onExit: nil, mode: .acceptanceFlow)
        }
        .preferredColorScheme(.dark)
        .colorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
        .previewDisplayName("11 Pro dark")
    }
}
