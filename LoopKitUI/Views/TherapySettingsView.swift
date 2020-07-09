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

public protocol TherapySettingsViewDelegate: class {
    func gotoEdit(therapySetting: TherapySetting)
    func save()
}

public class TherapySettingsViewModel: ObservableObject {
    var therapySettings: TherapySettings
    
    init(therapySettings: TherapySettings) {
        self.therapySettings = therapySettings
    }
}

public struct TherapySettingsView: View, HorizontalSizeClassOverride {
    @Environment(\.dismiss) var dismiss

    weak var delegate: TherapySettingsViewDelegate?
    
    @ObservedObject var viewModel: TherapySettingsViewModel

    @State var isEditing: Bool = false
    //    static let unit = HKUnit.milligramsPerDeciliter
//    let unit = Self.unit
//    // Blarg, why doesn't @State work here???
////    @State var scheduleItems: [RepeatingScheduleValue<DoubleRange>] = []
//    let scheduleItems: [RepeatingScheduleValue<DoubleRange>]
    
    public enum PresentationMode {
        case onboarding, settings
    }
    private let mode: PresentationMode
    
    public init(mode: PresentationMode = .settings, viewModel: TherapySettingsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
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
            NavigationLink(destination: Text("Edit Correction Range")) { Text("Edit Correction Range") }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle(Text(NSLocalizedString("Therapy Settings", comment: "Therapy Settings screen title")))
        .navigationBarItems(trailing: editOrDismissButton)
        .environment(\.horizontalSizeClass, horizontalOverride)
    }
}

typealias HKQuantityGuardrail = Guardrail<HKQuantity>

extension TherapySettingsView {
    
    private var editOrDismissButton: some View {
        Button( action: {
            if !self.isEditing {
                self.isEditing.toggle()
            } else {
                self.delegate?.save()
                self.dismiss()
            }
        }) {
            if isEditing {
                Text(NSLocalizedString("Done", comment: "Done button text"))
            } else {
                Text(NSLocalizedString("Edit", comment: "Edit button text"))
            }
        }
    }
        
    private var correctionRangeSection: some View {
        Section(header: SectionHeaderWithEdit(isEditing: $isEditing, title: "Correction Range")) {
            ForEach(self.viewModel.therapySettings.glucoseTargetRangeSchedule?.items ?? [], id: \.self) { value in
                self.scheduleItemRange(time: value.startTime, range: value.value, unit: self.viewModel.therapySettings.glucoseTargetRangeSchedule?.unit ?? .milligramsPerDeciliter, guardrail: Guardrail.correctionRange)
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
    
    private func header(title: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionHeader(label: title)
            Spacer()
            Button(action: {}) {
                Text("Edit").font(.subheadline)
            }
        }
    }
}

struct SectionHeaderWithEdit: View {
    @Binding var isEditing: Bool
    var title: String
    
    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionHeader(label: title)
            Spacer()
            Button(action: {}) {
                Text("Edit")
                    .font(.subheadline)
            }.disabled(!isEditing)
        }
    }
}

// For previews:
fileprivate let glucoseScheduleItems = [
    RepeatingScheduleValue(startTime: 0, value: DoubleRange(80...90)),
    RepeatingScheduleValue(startTime: 1800, value: DoubleRange(90...100)),
    RepeatingScheduleValue(startTime: 3600, value: DoubleRange(100...110))
]

fileprivate let therapySettings = TherapySettings(
    glucoseTargetRangeSchedule: GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: glucoseScheduleItems),
    preMealTargetRange: nil,
    legacyWorkoutTargetRange: nil,
    maximumBasalRatePerHour: nil,
    maximumBolus: nil,
    suspendThreshold: nil,
    insulinSensitivitySchedule: nil,
    carbRatioSchedule: nil)

public struct TherapySettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        TherapySettingsView(viewModel: TherapySettingsViewModel(therapySettings: therapySettings))
    }
}

extension DoubleRange {
    init(_ val: ClosedRange<Double>) {
        self.init(minValue: val.lowerBound, maxValue: val.upperBound)
    }
}
