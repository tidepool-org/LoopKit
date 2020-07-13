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

public class TherapySettingsViewModel: ObservableObject {
    private var initialTherapySettings: TherapySettings
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
    
    // Hack to test edit button below section or next to header
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

    public enum PresentationMode {
        case onboarding, settings
    }
    private let mode: PresentationMode
    
    public init(mode: PresentationMode = .settings, editButtonDesignVersion: DesignVersion = .C, viewModel: TherapySettingsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        self.editButtonDesignVersion = editButtonDesignVersion
    }
    
    public var body: some View {
        switch mode {
        case .settings: return AnyView(content())
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
            temporaryCorrectionRangesSection
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle(Text(NSLocalizedString("Therapy Settings", comment: "Therapy Settings screen title")))
        .navigationBarItems(leading: backOrCancelButton, trailing: editOrDoneButton)
        .environment(\.horizontalSizeClass, horizontalOverride)
    }
}

typealias HKQuantityGuardrail = Guardrail<HKQuantity>

extension TherapySettingsView {
    
    // TODO: Something better than this?
    private var unit: HKUnit {
        self.viewModel.therapySettings.glucoseTargetRangeSchedule?.unit ?? .milligramsPerDeciliter
    }
    
    private var backOrCancelButton: some View {
        return Button<AnyView>( action: {
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
                return AnyView(Text(NSLocalizedString("Cancel", comment: "Cancel button text")))
            } else {
                switch mode {
                    case .settings: return AnyView(EmptyView())
                    case .onboarding: return AnyView(Text(NSLocalizedString("Back", comment: "Back button text")))
                }
            }
        }
    }
    
    private var editOrDoneButton: some View {
        let action = {
            if self.isEditing {
                // TODO: confirm
                self.delegate?.save()
            }
            self.isEditing.toggle()
        }
        return Button( action: action ) {
            Group {
                if isEditing {
                    Text(NSLocalizedString("Done", comment: "Done button text"))
                } else {
                    Text(NSLocalizedString("Edit", comment: "Edit button text"))
                }
            }
            .onTapGesture {
                action()
            }
            .onLongPressGesture {
                self.editButtonDesignVersion = self.editButtonDesignVersion.cycle()
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            }
        }
    }
    
    private var correctionRangeSection: some View {
        SectionWithEdit(isEditing: $isEditing,
                        editButtonDesignVersion: $editButtonDesignVersion,
                        title: NSLocalizedString("Correction Range", comment: "Correction Range section title"),
                        footer: EmptyView(),
                        gotoEdit: { self.delegate?.gotoEdit(therapySetting: TherapySetting.glucoseTargetRange) })
        {
            ForEach(self.viewModel.therapySettings.glucoseTargetRangeSchedule?.items ?? [], id: \.self) { value in
                ScheduledRangeItem(time: value.startTime, range: value.value, unit: self.unit, guardrail: Guardrail.correctionRange)
            }
        }
    }
    
    private var temporaryCorrectionRangesSection: some View {
        SectionWithEdit(isEditing: $isEditing,
                        editButtonDesignVersion: $editButtonDesignVersion,
                        title: NSLocalizedString("Temporary Correction Ranges", comment: "Temporary Correction Ranges section title"),
                        footer: EmptyView(),
                        gotoEdit: { self.delegate?.gotoEdit(therapySetting: TherapySetting.correctionRangeOverrides) })
        {
            Group {
                if self.viewModel.therapySettings.glucoseTargetRangeSchedule != nil {
                    ForEach([ CorrectionRangeOverrides.Preset.preMeal, CorrectionRangeOverrides.Preset.workout  ], id: \.self) { preset in
                        CorrectionRangeOverridesRangeItem(
                            preMealTargetRange: self.viewModel.therapySettings.preMealTargetRange,
                            workoutTargetRange: self.viewModel.therapySettings.workoutTargetRange,
                            unit: self.unit,
                            preset: preset,
                            correctionRangeScheduleRange: self.viewModel.therapySettings.glucoseTargetRangeSchedule!.scheduleRange()
                        )
                    }
                } else {
                    EmptyView()
                }
            }
        }
    }
    
}

struct ScheduledRangeItem: View {
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
    let gotoEdit: () -> Void
    let content: () -> Content

    public var body: some View {
        buildBody()
    }
    
    @ViewBuilder private func buildBody() -> some View {
        Section(header: SectionHeaderWithEdit(isEditing: $isEditing,
                                              editButtonDesignVersion: $editButtonDesignVersion,
                                              title: title,
                                              editAction: { self.gotoEdit() }
        ), footer: footer) {
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
        Button(action: { self.gotoEdit() }) {
            HStack {
                Text("Edit \(title)")
                Spacer()
                // TODO: Ick. I can't use a NavigationLink because we're not Navigating, but this seems worse somehow.
                Image(systemName: "chevron.right").foregroundColor(.gray).font(.footnote)
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
            TherapySettingsView(mode: .onboarding, editButtonDesignVersion: .A, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (onboarding)")
            TherapySettingsView(mode: .onboarding, editButtonDesignVersion: .B, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (edit below section)")
            TherapySettingsView(mode: .onboarding, editButtonDesignVersion: .C, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (edit below section)")
            TherapySettingsView(mode: .settings, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light (settings)")
            TherapySettingsView(mode: .onboarding, viewModel: TherapySettingsViewModel(therapySettings: preview_therapySettings))
                .colorScheme(.dark)
                .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                .previewDisplayName("XS Max dark (settings)")
        }
    }
}
