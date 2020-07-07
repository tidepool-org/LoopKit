//
//  CorrectionRangeScheduleEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


extension Guardrail where Value == HKQuantity {
    public static let correctionRange = Guardrail(absoluteBounds: 60...180, recommendedBounds: 70...120, unit: .milligramsPerDeciliter)
}

public struct CorrectionRangeScheduleEditor: View {
    var initialSchedule: GlucoseRangeSchedule?
    @State var scheduleItems: [RepeatingScheduleValue<DoubleRange>]
    var unit: HKUnit
    var minValue: HKQuantity?
    var save: (GlucoseRangeSchedule) -> Void
    let guardrail = Guardrail.correctionRange
    let mode: PresentationMode
    @State private var userDidTap: Bool = false
    
    public init(
        schedule: GlucoseRangeSchedule?,
        unit: HKUnit,
        minValue: HKQuantity?,
        onSave save: @escaping (GlucoseRangeSchedule) -> Void,
        mode: PresentationMode = .modal,
        userHasEdited: Binding<Bool> = Binding.constant(false)
    ) {
        self.initialSchedule = schedule
        self._scheduleItems = State(initialValue: schedule?.items ?? [])
        self.unit = unit
        self.minValue = minValue
        self.save = save
        self.mode = mode
    }

    public var body: some View {
        ScheduleEditor(
            title: Text("Correction Ranges", comment: "Title of correction range schedule editor"),
            description: description,
            buttonText: buttonText,
            scheduleItems: $scheduleItems,
            initialScheduleItems: initialSchedule?.items ?? [],
            defaultFirstScheduleItemValue: defaultFirstScheduleItemValue,
            saveConfirmation: saveConfirmation,
            valueContent: { range, isEditing in
                GuardrailConstrainedQuantityRangeView(range: range.quantityRange(for: self.unit), unit: self.unit, guardrail: self.guardrail, isEditing: isEditing)
            },
            valuePicker: { scheduleItem, availableWidth in
                GlucoseRangePicker(
                    range: Binding(
                        get: { scheduleItem.wrappedValue.value.quantityRange(for: self.unit) },
                        set: { quantityRange in
                            withAnimation {
                                scheduleItem.wrappedValue.value = quantityRange.doubleRange(for: self.unit)
                            }
                        }
                    ),
                    unit: self.unit,
                    minValue: self.minValue,
                    guardrail: self.guardrail,
                    usageContext: .component(availableWidth: availableWidth)
                )
            },
            actionAreaContent: {
                instructionalContentIfNecessary
                guardrailWarningIfNecessary
            },
            savingMechanism: .synchronous { items in
                let quantitySchedule = DailyQuantitySchedule(unit: self.unit, dailyItems: items)!
                let rangeSchedule = GlucoseRangeSchedule(rangeSchedule: quantitySchedule, override: self.initialSchedule?.override)
                self.save(rangeSchedule)
            },
            mode: mode,
            therapySettingType: .glucoseTargetRange
        )
        .onTapGesture {
            self.userDidTap = true
        }
    }

    var defaultFirstScheduleItemValue: DoubleRange {
        switch unit {
        case .milligramsPerDeciliter:
            return DoubleRange(minValue: 100, maxValue: 120)
        case .millimolesPerLiter:
            return DoubleRange(minValue: 5.6, maxValue: 6.7)
        default:
            fatalError("Unsupposed glucose unit \(unit)")
        }
    }

    var description: Text {
        Text("The app adjusts insulin delivery in an effort to bring your glucose into your correction range.", comment: "Description of correction range setting")
    }

    var saveConfirmation: SaveConfirmation {
        crossedThresholds.isEmpty ? .notRequired : .required(confirmationAlertContent)
    }
    
    var instructionalContentIfNecessary: some View {
        return Group {
            if mode == .flow && !userDidTap {
                instructionalContent
            }
        }
    }
    
    var instructionalContent: some View {
        HStack { // to align with guardrail warning, if present
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedString("You can edit a setting by tapping into any line item.", comment: "Description of how to edit setting"))
                Text(LocalizedString("You can add different correction ranges for different times of day by using the [+].", comment: "Description of how to add a configuration range"))
            }
            .foregroundColor(.accentColor)
            .font(.subheadline)
            Spacer()
        }
    }

    var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.crossedThresholds
        return Group {
            if !crossedThresholds.isEmpty && (userDidTap || mode == .modal) {
                CorrectionRangeGuardrailWarning(crossedThresholds: crossedThresholds)
            }
        }
    }

    var crossedThresholds: [SafetyClassification.Threshold] {
        scheduleItems.flatMap { (item) -> [SafetyClassification.Threshold] in
            let lowerBound = HKQuantity(unit: unit, doubleValue: item.value.minValue)
            let upperBound = HKQuantity(unit: unit, doubleValue: item.value.maxValue)
            return [lowerBound, upperBound].compactMap { (bound) -> SafetyClassification.Threshold? in
                switch guardrail.classification(for: bound) {
                case .withinRecommendedRange:
                    return nil
                case .outsideRecommendedRange(let threshold):
                    return threshold
                }
            }
        }
    }
    
    private var buttonText: Text {
        switch mode {
        case .modal:
            return Text("Save", comment: "The button text for saving on a configuration page")
        case .flow:
            return self.initialSchedule?.items == scheduleItems ? Text(LocalizedString("Accept Setting", comment: "The button text for accepting the prescribed setting")) : Text(LocalizedString("Save Setting", comment: "The button text for saving the edited setting"))
        }
    }

    private var confirmationAlertContent: AlertContent {
        AlertContent(
            title: Text("Save Correction Range(s)?", comment: "Alert title for confirming correction ranges outside the recommended range"),
            message: Text("One or more of the values you have entered are outside of what Tidepool generally recommends.", comment: "Alert message for confirming correction ranges outside the recommended range")
        )
    }
}

private struct CorrectionRangeGuardrailWarning: View {
    var crossedThresholds: [SafetyClassification.Threshold]

    var body: some View {
        assert(!crossedThresholds.isEmpty)
        return GuardrailWarning(
            title: crossedThresholds.count == 1 ? singularWarningTitle(for: crossedThresholds.first!) : multipleWarningTitle,
            thresholds: crossedThresholds
        )
    }

    private func singularWarningTitle(for threshold: SafetyClassification.Threshold) -> Text {
        switch threshold {
        case .minimum, .belowRecommended:
            return Text("Low Correction Value", comment: "Title text for the low correction value warning")
        case .aboveRecommended, .maximum:
            return Text("High Correction Value", comment: "Title text for the high correction value warning")
        }
    }

    private var multipleWarningTitle: Text {
        Text("Correction Values", comment: "Title text for multi-value correction value warning")
    }
}
