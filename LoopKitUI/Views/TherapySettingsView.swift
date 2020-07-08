//
//  TherapySettingsView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import SwiftUI

public struct TherapySettingsView: View, HorizontalSizeClassOverride {
    @Environment(\.dismiss) var dismiss

    static let unit = HKUnit.milligramsPerDeciliter
    let unit = Self.unit
    @State var scheduleItems: [RepeatingScheduleValue<DoubleRange>] = []

    public enum PresentationMode {
        case onboarding, settings
    }
    private let mode: PresentationMode
    
    public init(mode: PresentationMode = .settings) {
        self.mode = mode
    }
    
    public var body: some View {
        switch mode {
        case .settings: return AnyView(navigationContent())
        case .onboarding: return AnyView(navigationContent())
        }
    }
    
    private func navigationContent() -> some View {
        return NavigationView {
            content()
        }
    }
    
    private func content() -> some View {
        List {
            correctionRangeSection
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle(Text(NSLocalizedString("Therapy Settings", comment: "Therapy Settings screen title")))
        .navigationBarItems(trailing: dismissButton)
        .environment(\.horizontalSizeClass, horizontalOverride)
    }
}

//private let glucoseTargetRangeSchedule = GlucoseRangeSchedule(
//    rangeSchedule: DailyQuantitySchedule(
//        unit: .milligramsPerDeciliter,
//        dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
//                     RepeatingScheduleValue(startTime: .hours(7), value: DoubleRange(minValue: 90.0, maxValue: 100.0)),
//                     RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 110.0, maxValue: 120.0))],
//        timeZone: TimeZone(identifier: "America/Los_Angeles")!)!,
//    override: GlucoseRangeSchedule.Override(value: DoubleRange(minValue: 105.0, maxValue: 115.0),
//                                            start: ISO8601DateFormatter().date(from: "2020-05-14T21:12:17Z")!,
//                                            end: ISO8601DateFormatter().date(from: "2020-05-14T23:12:17Z")!))


extension TherapySettingsView {
    private var dismissButton: some View {
        Button( action: { self.dismiss() }) {
            Text(NSLocalizedString("Done", comment: "Done button text"))
        }
    }
    
    private var correctionRangeSection: some View {
        Section(header: SectionHeader(label: "Correction Range"))   {
            ScheduleItemView(time: .hours(0), isEditing: false, valueContent: {
                GuardrailConstrainedQuantityRangeView(range: DoubleRange(100...110).quantityRange(for: unit), unit: unit, guardrail: Guardrail.correctionRange, isEditing: false)
            }, expandedContent: <#T##() -> _#>)
        }
    }
}

public struct TherapySettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        TherapySettingsView()
    }
}


extension DoubleRange {
    init(_ val: ClosedRange<Double>) {
        self.init(minValue: val.lowerBound, maxValue: val.upperBound)
    }
}
