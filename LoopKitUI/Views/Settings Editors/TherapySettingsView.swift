//
//  TherapySettingsView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import AVFoundation
import HealthKit
import LoopKit
import SwiftUI

typealias HKQuantityGuardrail = Guardrail<HKQuantity>

public protocol TherapySettingsViewDelegate: class {
    func gotoEdit(therapySetting: TherapySetting)
    func save()
    func cancel()
}

public struct TherapySettingsView: View, HorizontalSizeClassOverride {
    @Environment(\.dismiss) var dismiss
    
    weak var delegate: TherapySettingsViewDelegate?
    
    @ObservedObject var viewModel: TherapySettingsViewModel
    
    @State var isEditing: Bool = false
    
    private let mode: PresentationMode
    
    public init(mode: PresentationMode = .flow, viewModel: TherapySettingsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
    }
    
    public var body: some View {
        switch mode {
        // TODO: Different versions for onboarding vs. in settings
        case .flow: return AnyView(content)
        case .modal: return AnyView(navigationContent)
        }
    }
    
    private var content: some View {
        List {
            correctionRangeSection
            temporaryCorrectionRangesSection
            suspendThresholdSection
            basalRatesSection
            deliveryLimitsSection
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle(Text(LocalizedString("Therapy Settings", comment: "Therapy Settings screen title")))
        .navigationBarItems(leading: backOrCancelButton, trailing: editOrDoneButton)
        .navigationBarBackButtonHidden(isEditing)
        .environment(\.horizontalSizeClass, horizontalOverride)
    }
    
    private var navigationContent: some View {
        NavigationView {
            content
        }
    }
}

// MARK: Buttons
extension TherapySettingsView {
    
    private var backOrCancelButton: some View {
        if self.isEditing {
            return AnyView(cancelButton)
        } else {
            return AnyView(backButton)
        }
    }
    
    private var backButton: some View {
        return Button<AnyView>( action: { self.dismiss() }) {
            switch mode {
            case .flow: return AnyView(EmptyView())
            case .modal: return AnyView(Text(LocalizedString("Back", comment: "Back button text")))
            }
        }
    }
    
    private var cancelButton: some View {
        return Button( action: {
            // TODO: confirm
            self.delegate?.cancel()
            self.viewModel.reset()
            self.isEditing.toggle()
        })
        {
            Text(LocalizedString("Cancel", comment: "Cancel button text"))
        }
    }
    
    private var editOrDoneButton: some View {
        if self.isEditing {
            return AnyView(doneButton)
        } else {
            return AnyView(editButton)
        }
    }
    
    private var editButton: some View {
        return Button( action: {
            self.isEditing.toggle()
        }) {
            Text(LocalizedString("Edit", comment: "Edit button text"))
        }
    }
    
    private var doneButton: some View {
        return Button( action: {
            // TODO: confirm
            self.delegate?.save()
            self.isEditing.toggle()
        }) {
            Text(LocalizedString("Done", comment: "Done button text"))
        }
    }
}

// MARK: Sections
extension TherapySettingsView {
    
    private var correctionRangeSection: some View {
        section(for: .glucoseTargetRange) {
            Group {
                if self.glucoseUnit != nil && self.therapySettings.glucoseTargetRangeSchedule != nil {
                    ForEach(self.therapySettings.glucoseTargetRangeSchedule!.items, id: \.self) { value in
                        ScheduleRangeItem(time: value.startTime,
                                          range: value.value,
                                          unit: self.glucoseUnit!,
                                          guardrail: .correctionRange)
                    }
                } else {
                    DescriptiveText(label: LocalizedString("Tap \"Edit\" to add a Correction Range", comment: "Correction Range section edit hint"))
                }
            }
        }
    }
    
    private var temporaryCorrectionRangesSection: some View {
        section(for: .correctionRangeOverrides) {
            Group {
                if self.glucoseUnit != nil && self.therapySettings.glucoseTargetRangeSchedule != nil {
                    ForEach(CorrectionRangeOverrides.Preset.allCases, id: \.self) { preset in
                        CorrectionRangeOverridesRangeItem(
                            preMealTargetRange: self.therapySettings.preMealTargetRange,
                            workoutTargetRange: self.therapySettings.workoutTargetRange,
                            unit: self.glucoseUnit!,
                            preset: preset,
                            correctionRangeScheduleRange: self.therapySettings.glucoseTargetRangeSchedule!.scheduleRange()
                        )
                    }
                }
            }
        }
    }
    
    private var suspendThresholdSection: some View {
        section(for: .suspendThreshold) {
            Group {
                if self.glucoseUnit != nil {
                    HStack {
                        Spacer()
                        GuardrailConstrainedQuantityView(
                            value: self.therapySettings.suspendThreshold?.quantity,
                            unit: self.glucoseUnit!,
                            guardrail: .suspendThreshold,
                            isEditing: false,
                            // Workaround for strange animation behavior on appearance
                            forceDisableAnimations: true
                        )
                    }
                }
            }
        }
    }
    
    private var basalRatesSection: some View {
        section(for: .basalRate) {
            Group {
                if self.therapySettings.basalRateSchedule != nil && self.viewModel.supportedBasalRates != nil {
                    ForEach(self.therapySettings.basalRateSchedule!.items, id: \.self) { value in
                        ScheduleValueItem(time: value.startTime,
                                          value: value.value,
                                          unit: .internationalUnitsPerHour,
                                          guardrail: Guardrail.basalRate(supportedBasalRates: self.viewModel.supportedBasalRates!))
                    }
                }
            }
        }
    }
    
    private var deliveryLimitsSection: some View {
        section(for: .deliveryLimits) {
            HStack {
                Text(LocalizedString("Maximum Basal Rate", comment: "Maximum Basal Rate settings item title"))
                Spacer()
                Group {
                    if self.viewModel.supportedBasalRates != nil {
                        
                        GuardrailConstrainedQuantityView(
                            value: self.therapySettings.maximumBasalRatePerHour == nil ? nil : HKQuantity(unit: .internationalUnitsPerHour, doubleValue: self.therapySettings.maximumBasalRatePerHour!),
                            unit: .internationalUnitsPerHour,
                            guardrail: Guardrail.maximumBasalRate(supportedBasalRates: self.viewModel.supportedBasalRates!, scheduledBasalRange: self.therapySettings.basalRateSchedule?.valueRange()),
                            isEditing: false,
                            // Workaround for strange animation behavior on appearance
                            forceDisableAnimations: true
                        )
                    }
                }
            }
        }
    }
}

// MARK: Utilities
extension TherapySettingsView {
    
    private var therapySettings: TherapySettings {
        viewModel.therapySettings
    }
    
    private var glucoseUnit: HKUnit? {
        therapySettings.glucoseTargetRangeSchedule?.unit
    }
    
    private var sensitivityUnit: HKUnit? {
        glucoseUnit?.unitDivided(by: .internationalUnit())
    }

    private func section<Content>(for therapySetting: TherapySetting, content: @escaping () -> Content) -> some View where Content: View {
        SectionWithEdit(isEditing: $isEditing,
                        title: therapySetting.title,
                        descriptiveText: therapySetting.descriptiveText,
                        editAction: { self.delegate?.gotoEdit(therapySetting: therapySetting) },
                        content: content)
    }

}

struct ScheduleRangeItem: View {
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

struct ScheduleValueItem: View {
    let time: TimeInterval
    let value: Double
    let unit: HKUnit
    let guardrail: HKQuantityGuardrail
    
    public var body: some View {
        ScheduleItemView(time: time,
                         isEditing: .constant(false),
                         valueContent: {
                            GuardrailConstrainedQuantityView(value: HKQuantity(unit: unit, doubleValue: value), unit: unit, guardrail: guardrail, isEditing: false)
                         },
                         expandedContent: { EmptyView() })
    }
}

struct CorrectionRangeOverridesRangeItem: View {
    let preMealTargetRange: DoubleRange?
    let workoutTargetRange: DoubleRange?
    let unit: HKUnit
    let preset: CorrectionRangeOverrides.Preset
    let correctionRangeScheduleRange: ClosedRange<HKQuantity>
    
    public var body: some View {
        CorrectionRangeOverridesExpandableSetting(
            isEditing: .constant(false),
            value: .constant(CorrectionRangeOverrides(
                preMeal: preMealTargetRange,
                workout: workoutTargetRange,
                unit: unit
            )),
            preset: preset,
            unit: unit,
            correctionRangeScheduleRange: correctionRangeScheduleRange,
            expandedContent: { EmptyView() })
    }
}

// Note: I didn't call this "EditableSection" because it doesn't actually make the section editable,
// it just optionally provides a link to go to an editor screen.
struct SectionWithEdit<Content>: View where Content: View {
    @Binding var isEditing: Bool
    let title: String
    let descriptiveText: String
    let editAction: () -> Void
    let content: () -> Content
    
    @ViewBuilder public var body: some View {
        Section {
            VStack(alignment: .leading) {
                Spacer()
                Text(title)
                    .bold()
                Spacer()
                DescriptiveText(label: descriptiveText)
                Spacer()
            }
            content()
            if isEditing {
                navigationButton
            }
        }
    }
    
    private var navigationButton: some View {
        Button(action: { self.editAction() }) {
            HStack {
                Text(String(format: LocalizedString("Edit %@", comment: "The string format for the Edit navigation button"), title))
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray).font(.footnote)
            }
        }
        .disabled(!isEditing)
    }
}

// For previews:
let preview_glucoseScheduleItems = [
    RepeatingScheduleValue(startTime: 0, value: DoubleRange(80...90)),
    RepeatingScheduleValue(startTime: 1800, value: DoubleRange(90...100)),
    RepeatingScheduleValue(startTime: 3600, value: DoubleRange(100...110))
]

let preview_therapySettings = TherapySettings(
    glucoseTargetRangeSchedule: GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: preview_glucoseScheduleItems),
    preMealTargetRange: DoubleRange(88...99),
    workoutTargetRange: DoubleRange(99...111),
    maximumBasalRatePerHour: 55,
    maximumBolus: 4,
    suspendThreshold: GlucoseThreshold.init(unit: .milligramsPerDeciliter, value: 60),
    insulinSensitivitySchedule: InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter.unitDivided(by: HKUnit.internationalUnit()), dailyItems: []),
    carbRatioSchedule: nil,
    basalRateSchedule: BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: 0, value: 0.2), RepeatingScheduleValue(startTime: 1800, value: 0.75)]))

let preview_supportedBasalRates = [0.2, 0.5, 0.75, 1.0]

public struct TherapySettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        Group {
            TherapySettingsView(mode: .modal,viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings, supportedBasalRates: preview_supportedBasalRates))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (onboarding)")
            TherapySettingsView(mode: .flow, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings, supportedBasalRates: preview_supportedBasalRates))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (settings)")
            TherapySettingsView(mode: .modal, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings, supportedBasalRates: preview_supportedBasalRates))
                .colorScheme(.dark)
                .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                .previewDisplayName("XS Max dark (settings)")
            TherapySettingsView(mode: .modal, viewModel: TherapySettingsViewModel(therapySettings: TherapySettings(), supportedBasalRates: nil))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (Empty TherapySettings)")
        }
    }
}
