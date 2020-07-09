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

    // TODO: More ViewModel! (cowbell!)
    static let unit = HKUnit.milligramsPerDeciliter
    let unit = Self.unit
    // Blarg, why doesn't @State work here???
//    @State var scheduleItems: [RepeatingScheduleValue<DoubleRange>] = []
    let scheduleItems: [RepeatingScheduleValue<DoubleRange>]

    public enum PresentationMode {
        case onboarding, settings
    }
    private let mode: PresentationMode
    
    public init(mode: PresentationMode = .settings, scheduleItems: [RepeatingScheduleValue<DoubleRange>] = []) {
        self.mode = mode
        self.scheduleItems = scheduleItems
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

typealias HKQuantityGuardrail = Guardrail<HKQuantity>

extension TherapySettingsView {
    private var dismissButton: some View {
        Button( action: { self.dismiss() }) {
            Text(NSLocalizedString("Done", comment: "Done button text"))
        }
    }
        
    private var correctionRangeSection: some View {
        Section(header: SectionHeader(label: "Correction Range")) {
            ForEach(scheduleItems, id: \.self) { value in
                self.scheduleItemRange(time: value.startTime, range: value.value, unit: self.unit, guardrail: Guardrail.correctionRange)
            }
        }
    }
    
    private func scheduleItemRange(time: TimeInterval, range: DoubleRange, unit: HKUnit, guardrail: HKQuantityGuardrail) -> some View {
        ScheduleItemView(time: time,
                         isEditing: .constant(false),
                         valueContent: {
                            GuardrailConstrainedQuantityRangeView(range: range.quantityRange(for: unit), unit: unit, guardrail: guardrail, isEditing: false)
                         },
                         expandedContent: { EmptyView() })
    }
}

public struct TherapySettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        TherapySettingsView(mode: .settings, scheduleItems: [
            RepeatingScheduleValue(startTime: 0, value: DoubleRange(100...110)),
            RepeatingScheduleValue(startTime: 1800, value: DoubleRange(120...150)),
            RepeatingScheduleValue(startTime: 3600, value: DoubleRange(150...200))
        ])
    }
}

extension DoubleRange {
    init(_ val: ClosedRange<Double>) {
        self.init(minValue: val.lowerBound, maxValue: val.upperBound)
    }
}
