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
    
    // Hack to test edit button below section or next to header
    // TODO: Remove once design is chosen
    public enum DesignVersion {
        case A, B, C
        func cycle() -> DesignVersion {
            switch self {
            case .A: return .B
            case .B: return .C
            case .C: return .A
            }
        }
    }
    @State var editButtonDesignVersion: DesignVersion = .C

    private let mode: PresentationMode
    
    public init(mode: PresentationMode = .flow, editButtonDesignVersion: DesignVersion = .C, viewModel: TherapySettingsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        self.editButtonDesignVersion = editButtonDesignVersion
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

typealias HKQuantityGuardrail = Guardrail<HKQuantity>

extension TherapySettingsView {
    
    private var therapySettings: TherapySettings {
        viewModel.therapySettings
    }
    
    private var glucoseUnit: HKUnit? {
        therapySettings.glucoseTargetRangeSchedule?.unit
    }
    
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
        let action = {
            self.isEditing.toggle()
        }
        return Button( action: action ) {
            Text(LocalizedString("Edit", comment: "Edit button text"))
            .onTapGesture {
                action()
            }
            // TODO: Remove once design is chosen
            .onLongPressGesture {
                self.editButtonDesignVersion = self.editButtonDesignVersion.cycle()
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            }
        }
    }
    
    private var doneButton: some View {
        let action = {
            // TODO: confirm
            self.delegate?.save()
            self.isEditing.toggle()
        }
        return Button( action: action ) {
            Text(LocalizedString("Done", comment: "Done button text"))
            .onTapGesture {
                action()
            }
            // TODO: Remove once design is chosen
            .onLongPressGesture {
                self.editButtonDesignVersion = self.editButtonDesignVersion.cycle()
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            }
        }
    }
    
    private var correctionRangeSection: some View {
        SectionWithEdit(isEditing: $isEditing,
                        editButtonDesignVersion: $editButtonDesignVersion,
                        title: LocalizedString("Correction Range", comment: "Correction Range section title"),
                        footer: EmptyView(),
                        editAction: { self.delegate?.gotoEdit(therapySetting: TherapySetting.glucoseTargetRange) })
        {
            Group {
                if self.glucoseUnit != nil && self.therapySettings.glucoseTargetRangeSchedule != nil {
                    ForEach(self.therapySettings.glucoseTargetRangeSchedule!.items, id: \.self) { value in
                        ScheduleRangeItem(time: value.startTime, range: value.value, unit: self.glucoseUnit!, guardrail: Guardrail.correctionRange)
                    }
                } else {
                    DescriptiveText(label: LocalizedString("Tap \"Edit\" to add a Correction Range", comment: "Correction Range section edit hint"))
                }
            }
        }
    }
    
    private var temporaryCorrectionRangesSection: some View {
        SectionWithEdit(isEditing: $isEditing,
                        editButtonDesignVersion: $editButtonDesignVersion,
                        title: LocalizedString("Temporary Correction Ranges", comment: "Temporary Correction Ranges section title"),
                        footer: EmptyView(),
                        editAction: { self.delegate?.gotoEdit(therapySetting: TherapySetting.correctionRangeOverrides) })
        {
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

struct SectionHeaderWithEdit: View {
    @Binding var isEditing: Bool
    @Binding var editButtonDesignVersion: TherapySettingsView.DesignVersion
    let title: String
    let editAction: () -> Void

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionHeader(label: title)
            if isEditing && editButtonDesignVersion == .C {
                Spacer()
                Button(action: editAction) {
                    Text("Edit")
                        .font(.subheadline)

                }
                .disabled(!isEditing)
            }
        }
    }
}

// Note: I didn't call this "EditableSection" because it doesn't actually make the section editable,
// it just optionally provides a link to go to an editor screen.
struct SectionWithEdit<Content, Footer>: View where Content: View, Footer: View {
    @Binding var isEditing: Bool
    @Binding var editButtonDesignVersion: TherapySettingsView.DesignVersion
    let title: String
    let footer: Footer
    let editAction: () -> Void
    let content: () -> Content

    @ViewBuilder public var body: some View {
        Section(header: SectionHeaderWithEdit(isEditing: $isEditing,
                                              editButtonDesignVersion: $editButtonDesignVersion,
                                              title: title,
                                              editAction: editAction),
                footer: footer)
        {
            content()
            if isEditing && editButtonDesignVersion == .B {
                navigationButton
            }
        }
        if isEditing && editButtonDesignVersion == .A {
            navigationButton
        }
    }
    
    private var navigationButton: some View {
        Button(action: { self.editAction() }) {
            HStack {
                if editButtonDesignVersion == .B {
                    Spacer()
                }
                Text("Edit \(title)")
                Spacer()
                if editButtonDesignVersion == .A {
                    // TODO: Ick. I can't use a NavigationLink because we're not Navigating, but this seems worse somehow.
                    Image(systemName: "chevron.right").foregroundColor(.gray).font(.footnote)
                }
            }
        }
        .disabled(!isEditing)
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
    preMealTargetRange: DoubleRange(88...99),
    workoutTargetRange: DoubleRange(99...111),
    maximumBasalRatePerHour: 55,
    maximumBolus: 4,
    suspendThreshold: GlucoseThreshold.init(unit: .milligramsPerDeciliter, value: 123),
    insulinSensitivitySchedule: nil,
    carbRatioSchedule: nil)

public struct TherapySettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        Group {
            TherapySettingsView(mode: .modal, editButtonDesignVersion: .A, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (onboarding)")
            TherapySettingsView(mode: .modal, editButtonDesignVersion: .B, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (edit below section)")
            TherapySettingsView(mode: .modal, editButtonDesignVersion: .C, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (edit below section)")
            TherapySettingsView(mode: .flow, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (settings)")
            TherapySettingsView(mode: .modal, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.dark)
                .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                .previewDisplayName("XS Max dark (settings)")
            TherapySettingsView(mode: .modal, editButtonDesignVersion: .A, viewModel: TherapySettingsViewModel(therapySettings: TherapySettings()))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (Empty TherapySettings)")

        }
    }
}
