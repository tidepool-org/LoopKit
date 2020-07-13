//
//  CorrectionRangeOverridesExpandableSetting.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


public struct CorrectionRangeOverridesExpandableSetting<ExpandedContent: View>: View {
    @Binding var isEditing: Bool
    @Binding var value: CorrectionRangeOverrides
    let preset: CorrectionRangeOverrides.Preset
    let unit: HKUnit?
    var correctionRangeScheduleRange: ClosedRange<HKQuantity>?
    var expandedContent: () -> ExpandedContent

    public var body: some View {
        ExpandableSetting(
            isEditing: $isEditing,
            leadingValueContent: {
                HStack {
                    icon(for: preset)
                    name(of: preset)
                }
            },
            trailingValueContent: {
                GuardrailConstrainedQuantityRangeView(
                    range: value.ranges[preset],
                    unit: unit,
                    guardrail: self.guardrail(for: preset),
                    isEditing: isEditing,
                    forceDisableAnimations: true
                )
            },
            expandedContent: expandedContent
        )
    }
    
    private func name(of preset: CorrectionRangeOverrides.Preset) -> Text {
        switch preset {
        case .preMeal:
            return Text("Pre-Meal", comment: "Title for pre-meal mode configuration section")
        case .workout:
            return Text("Workout", comment: "Title for workout mode configuration section")
        }
    }

    private func icon(for preset: CorrectionRangeOverrides.Preset) -> some View {
        switch preset {
        case .preMeal:
            return icon(named: "Pre-Meal", tinted: Color(.COBTintColor))
        case .workout:
            return icon(named: "workout", tinted: Color(.glucoseTintColor))
        }
    }
    
    private func icon(named name: String, tinted color: Color) -> some View {
        Image(name)
            .renderingMode(.template)
            .foregroundColor(color)
    }
    
    private func guardrail(for preset: CorrectionRangeOverrides.Preset) -> Guardrail<HKQuantity>? {
        return Self.guardrail(given: correctionRangeScheduleRange, for: preset)
    }

    static func guardrail(given correctionRangeScheduleRange: ClosedRange<HKQuantity>?, for preset: CorrectionRangeOverrides.Preset) -> Guardrail<HKQuantity>? {
        guard let correctionRangeScheduleRange = correctionRangeScheduleRange else { return nil }
        switch preset {
        case .preMeal:
            return Guardrail(
                absoluteBounds: Guardrail.correctionRange.absoluteBounds,
                recommendedBounds: Guardrail.correctionRange.recommendedBounds.lowerBound...max(correctionRangeScheduleRange.lowerBound, Guardrail.correctionRange.recommendedBounds.lowerBound)
            )
        case .workout:
            return Guardrail(
                absoluteBounds: Guardrail.correctionRange.absoluteBounds,
                recommendedBounds: max(Guardrail.correctionRange.recommendedBounds.lowerBound, correctionRangeScheduleRange.lowerBound)...Guardrail.correctionRange.absoluteBounds.upperBound
            )
        }
    }
}
