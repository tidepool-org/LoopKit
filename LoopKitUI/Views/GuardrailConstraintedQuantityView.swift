//
//  GuardrailConstraintedQuantityView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


public struct GuardrailConstrainedQuantityView: View {
    var value: HKQuantity
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>
    var isEditing: Bool
    var formatter: NumberFormatter

    @State private var hasAppeared = false

    public init(value: HKQuantity, unit: HKUnit, guardrail: Guardrail<HKQuantity>, isEditing: Bool) {
        self.value = value
        self.unit = unit
        self.guardrail = guardrail
        self.isEditing = isEditing
        self.formatter = {
            let quantityFormatter = QuantityFormatter()
            quantityFormatter.setPreferredNumberFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
    }

    public var body: some View {
        HStack {
            if guardrail.classification(for: value) != .withinRecommendedRange {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(warningColor)
                    .transition(.springInScaleOut)
            }

            Text(formatter.string(from: value.doubleValue(for: unit)) ?? "\(value.doubleValue(for: unit))")
                .foregroundColor(warningColor)

            Text(unit.shortLocalizedUnitString())
                .foregroundColor(Color(.secondaryLabel))
        }
        // A conditional implicit animation seems to behave funky on first appearance.
        // Disable animations until the view has appeared.
        .onAppear { self.hasAppeared = true }
        // While editing, the text width is liable to change, which can cause a slow-feeling animation
        // of the guardrail warning icon. Disable animations
        .animation(!hasAppeared || isEditing ? nil : .default)
    }

    private var warningColor: Color {
        switch guardrail.classification(for: value) {
        case .withinRecommendedRange:
            return isEditing ? .accentColor : .primary
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return .severeWarning
            case .belowRecommended, .aboveRecommended:
                return .warning
            }
        }
    }
}

fileprivate extension AnyTransition {
    static let springInScaleOut = asymmetric(
        insertion: AnyTransition.scale.animation(.spring(dampingFraction: 0.5)),
        removal: AnyTransition.scale.combined(with: .opacity).animation(.default)
    )
}
