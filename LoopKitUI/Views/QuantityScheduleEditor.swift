//
//  QuantityScheduleEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit

struct QuantityScheduleEditor<ActionAreaContent: View>: View {
    var title: Text
    var description: Text
    var initialScheduleItems: [RepeatingScheduleValue<Double>]
    @State var scheduleItems: [RepeatingScheduleValue<Double>]
    var unit: HKUnit
    var selectableValues: [Double]
    var guardrail: Guardrail<HKQuantity>
    var confirmationAlertContent: AlertContent
    var guardrailWarning: (_ crossedThresholds: [SafetyClassification.Threshold]) -> ActionAreaContent
    var save: (DailyQuantitySchedule<Double>) -> Void

    @Environment(\.dismiss) var dismiss
    @State var showingConfirmationAlert = false

    init(
        title: Text,
        description: Text,
        schedule: DailyQuantitySchedule<Double>?,
        unit: HKUnit,
        selectableValues: [Double],
        guardrail: Guardrail<HKQuantity>,
        confirmationAlertContent: AlertContent,
        @ViewBuilder guardrailWarning: @escaping (_ thresholds: [SafetyClassification.Threshold]) -> ActionAreaContent,
        onSave save: @escaping (DailyQuantitySchedule<Double>) -> Void
    ) {
        self.title = title
        self.description = description
        self.initialScheduleItems = schedule?.items ?? []
        self._scheduleItems = State(initialValue: schedule?.items ?? [])
        self.unit = unit
        self.selectableValues = selectableValues
        self.guardrail = guardrail
        self.confirmationAlertContent = confirmationAlertContent
        self.guardrailWarning = guardrailWarning
        self.save = save
    }

    init(
        title: Text,
        description: Text,
        schedule: DailyQuantitySchedule<Double>?,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        selectableValueStride: HKQuantity,
        confirmationAlertContent: AlertContent,
        @ViewBuilder guardrailWarning: @escaping (_ thresholds: [SafetyClassification.Threshold]) -> ActionAreaContent,
        onSave save: @escaping (DailyQuantitySchedule<Double>) -> Void
    ) {
        let selectableValues = guardrail.allValues(stridingBy: selectableValueStride, unit: unit)
        self.init(
            title: title,
            description: description,
            schedule: schedule,
            unit: unit,
            selectableValues: selectableValues,
            guardrail: guardrail,
            confirmationAlertContent: confirmationAlertContent,
            guardrailWarning: guardrailWarning,
            onSave: save
        )
    }

    var body: some View {
        ScheduleEditor(
            title: title,
            description: description,
            scheduleItems: $scheduleItems,
            initialScheduleItems: initialScheduleItems,
            valueContent: { value, isEditing in
                GuardrailConstrainedQuantityView(
                    value: HKQuantity(unit: self.unit, doubleValue: value),
                    unit: self.unit,
                    guardrail: self.guardrail,
                    isEditing: isEditing
                )
            },
            valuePicker: { item in
                QuantityPicker(
                    value: item.value.animation().withUnit(self.unit),
                    unit: self.unit,
                    guardrail: self.guardrail,
                    selectableValues: self.selectableValues
                )
            },
            actionAreaContent: {
                guardrailWarningIfNecessary
            },
            onSave: { _ in
                if self.crossedThresholds.isEmpty {
                    self.saveAndDismiss()
                } else {
                    self.showingConfirmationAlert = true
                }
            }
        )
        .alert(isPresented: $showingConfirmationAlert, content: confirmationAlert)
    }

    private var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.crossedThresholds
        return Group {
            if !crossedThresholds.isEmpty {
                guardrailWarning(crossedThresholds)
            }
        }
    }

    private var crossedThresholds: [SafetyClassification.Threshold] {
        scheduleItems.lazy
            .map { HKQuantity(unit: self.unit, doubleValue: $0.value) }
            .compactMap { quantity in
                switch guardrail.classification(for: quantity) {
                case .withinRecommendedRange:
                    return nil
                case .outsideRecommendedRange(let threshold):
                    return threshold
                }
        }
    }

    private func saveAndDismiss() {
        save(DailyQuantitySchedule(unit: unit, dailyItems: scheduleItems)!)
        dismiss()
    }

    private func confirmationAlert() -> Alert {
        Alert(
            title: confirmationAlertContent.title,
            message: confirmationAlertContent.message,
            primaryButton: .cancel(Text("Go Back")),
            secondaryButton: .default(
                Text("Continue"),
                action: saveAndDismiss
            )
        )
    }
}

extension Binding where Value == Double {
    func withUnit(_ unit: HKUnit) -> Binding<HKQuantity> {
        Binding<HKQuantity>(
            get: { HKQuantity(unit: unit, doubleValue: self.wrappedValue) },
            set: { self.wrappedValue = $0.doubleValue(for: unit) }
        )
    }
}
