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
    func cancel()
}

public class TherapySettingsViewModel: ObservableObject {
    var initialTherapySettings: TherapySettings
    var therapySettings: TherapySettings

    public init(therapySettings: TherapySettings = preview_therapySettings) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
    }
    
    /// Reset to original
    func reset() {
        therapySettings = initialTherapySettings
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
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle(Text(NSLocalizedString("Therapy Settings", comment: "Therapy Settings screen title")))
        .navigationBarItems(leading: backOrCancelButton, trailing: editOrDoneButton)
        .environment(\.horizontalSizeClass, horizontalOverride)
    }
}

typealias HKQuantityGuardrail = Guardrail<HKQuantity>

extension TherapySettingsView {
    
    private var backOrCancelButton: some View {
        Button( action: {
            if self.isEditing {
                // TODO: confirm
                self.delegate?.cancel()
                self.viewModel.reset()
                self.isEditing.toggle()
            } else {
                self.dismiss()
            }
        }) {
            if isEditing {
                Text(NSLocalizedString("Cancel", comment: "Cancel button text"))
            } else {
                Text(NSLocalizedString("Back", comment: "Back button text"))
            }
        }
    }
    
    private var editOrDoneButton: some View {
        Button( action: {
            if self.isEditing {
                // TODO: confirm
                self.delegate?.save()
            }
            self.isEditing.toggle()
        }) {
            if isEditing {
                Text(NSLocalizedString("Done", comment: "Done button text"))
            } else {
                Text(NSLocalizedString("Edit", comment: "Edit button text"))
            }
        }
    }

    private var correctionRangeSection: some View {
        SectionWithEdit(isEditing: $isEditing, title: "Correction Range", footer: EmptyView()) {
            ForEach(self.viewModel.therapySettings.glucoseTargetRangeSchedule?.items ?? [], id: \.self) { value in
                ScheduleItemRange(time: value.startTime, range: value.value, unit: self.viewModel.therapySettings.glucoseTargetRangeSchedule?.unit ?? .milligramsPerDeciliter, guardrail: Guardrail.correctionRange)
            }
        }
    }
}

struct ScheduleItemRange: View {
    let time: TimeInterval
    let range: DoubleRange
    let unit: HKUnit
    let guardrail: HKQuantityGuardrail
    
    public var body: some View {
        ScheduleItemView(time: time,
                         isEditing: .constant(false),
                         valueContent: {
                            GuardrailConstrainedQuantityRangeView(range: range.quantityRange(for: unit), unit: unit, guardrail: guardrail, isEditing: false)
                         },
                         expandedContent: { EmptyView() })
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

struct SectionWithEdit<Content, Footer>: View where Content: View, Footer: View {
    @Binding var isEditing: Bool
    let title: String
    let footer: Footer
    let content: () -> Content
    
    public var body: some View {
        buildBody()
    }
    
    @ViewBuilder private func buildBody() -> some View {
        Section(header: SectionHeaderWithEdit(isEditing: $isEditing, title: title), footer: footer) {
            content()
        }
        if isEditing {
            NavigationLink(destination: Text("Edit \(title)")) {
                Button(action: {}) {
                    Text("Edit \(title)")
                }.disabled(!isEditing)
            }.disabled(!isEditing)
        }
    }
}

// For previews:
public let preview_glucoseScheduleItems = [
    RepeatingScheduleValue(startTime: 0, value: DoubleRange(80...90)),
    RepeatingScheduleValue(startTime: 1800, value: DoubleRange(90...100)),
    RepeatingScheduleValue(startTime: 3600, value: DoubleRange(100...110))
]

public let preview_therapySettings = TherapySettings(
    glucoseTargetRangeSchedule: GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: preview_glucoseScheduleItems),
    preMealTargetRange: nil,
    legacyWorkoutTargetRange: nil,
    maximumBasalRatePerHour: nil,
    maximumBolus: nil,
    suspendThreshold: nil,
    insulinSensitivitySchedule: nil,
    carbRatioSchedule: nil)

public struct TherapySettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        TherapySettingsView(viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
    }
}

extension DoubleRange {
    init(_ val: ClosedRange<Double>) {
        self.init(minValue: val.lowerBound, maxValue: val.upperBound)
    }
}
