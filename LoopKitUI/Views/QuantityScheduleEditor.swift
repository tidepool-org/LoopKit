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
    @State var scheduleItems: [RepeatingScheduleValue<Double>]
    var unit: HKUnit
    var selectableValues: [Double]
    var guardrail: Guardrail<HKQuantity>
    var guardrailWarning: (_ crossedThresholds: [SafetyClassification.Threshold]) -> ActionAreaContent
    var save: (DailyQuantitySchedule<Double>) -> Void

    init(
        title: Text,
        description: Text,
        schedule: DailyQuantitySchedule<Double>?,
        unit: HKUnit,
        selectableValues: [Double],
        guardrail: Guardrail<HKQuantity>,
        @ViewBuilder guardrailWarning: @escaping (_ thresholds: [SafetyClassification.Threshold]) -> ActionAreaContent,
        onSave save: @escaping (DailyQuantitySchedule<Double>) -> Void
    ) {
        self.title = title
        self.description = description
        self._scheduleItems = State(initialValue: schedule?.items ?? [])
        self.unit = unit
        self.selectableValues = selectableValues
        self.guardrail = guardrail
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
            guardrailWarning: guardrailWarning,
            onSave: save
        )
    }

    var body: some View {
        ScheduleEditor(
            title: title,
            description: description,
            scheduleItems: $scheduleItems,
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
            onSave: {
                self.save(DailyQuantitySchedule(unit: self.unit, dailyItems: $0)!)
            }
        )
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
}

extension Binding where Value == Double {
    func withUnit(_ unit: HKUnit) -> Binding<HKQuantity> {
        Binding<HKQuantity>(
            get: { HKQuantity(unit: unit, doubleValue: self.wrappedValue) },
            set: { self.wrappedValue = $0.doubleValue(for: unit) }
        )
    }
}
