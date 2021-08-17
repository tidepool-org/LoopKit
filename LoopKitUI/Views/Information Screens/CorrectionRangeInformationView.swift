//
//  CorrectionRangeInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit

public struct CorrectionRangeInformationView: View {
    var onExit: (() -> Void)?
    var mode: SettingsPresentationMode

    @EnvironmentObject private var displayGlucoseUnitObserverable: DisplayGlucoseUnitObservable
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.appName) var appName

    private var displayGlucoseUnit: HKUnit {
        displayGlucoseUnitObserverable.displayGlucoseUnit
    }

    public init(onExit: (() -> Void)? = nil, mode: SettingsPresentationMode = .acceptanceFlow) {
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        GlucoseTherapySettingInformationView(
            therapySetting: .glucoseTargetRange,
            onExit: onExit,
            mode: mode,
            appName: appName,
            text: AnyView(text)
        )
    }
    
    private var text: some View {
        let glucoseRangeLower: ClosedRange<HKQuantity> = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 70)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 180)
        let glucoseRangeUpper: ClosedRange<HKQuantity> = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 90)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)
        return VStack(alignment: .leading, spacing: 25) {
            Text(String(format: LocalizedString("If you've used a CGM before, you're likely familiar with target range as a wide range of values you'd like for your glucose notification alerts, such as %1$@ or %2$@.", comment: "Information about target range (1: target range lower range (70-180 mg/dL), 2: target upper range (90-200 mg/dL))"), glucoseRangeLower.stringForGlucoseUnit(displayGlucoseUnit), glucoseRangeUpper.stringForGlucoseUnit(displayGlucoseUnit)))
            Text(LocalizedString("A Correction Range is different. This will be a narrower range.", comment: "Information about differences between target range and correction range"))
            .bold()
            Text(String(format: LocalizedString("For this range, choose the specific glucose value (or range of values) that you want %1$@ to aim for in adjusting your basal insulin.", comment: "Information about correction range format (1: app name)"), appName))
            Text(LocalizedString("Your healthcare provider can help you choose a Correction Range that's right for you.", comment: "Disclaimer"))
        }
        .foregroundColor(.secondary)
    }
}

struct CorrectionRangeInformationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CorrectionRangeInformationView()
                .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .milligramsPerDeciliter))
        }
        .colorScheme(.light)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
        .previewDisplayName("SE light")
        NavigationView {
            CorrectionRangeInformationView()
                .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .millimolesPerLiter))
        }
        .preferredColorScheme(.dark)
        .colorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
        .previewDisplayName("11 Pro dark")
    }
}
