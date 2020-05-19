//
//  FractionalQuantityPicker.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/18/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


fileprivate extension FloatingPoint {
    var whole: Self { modf(self).0 }
    var fraction: Self { modf(self).1 }

    func roundedToHundredths() -> Self {
        (self * 100).rounded() / 100
    }
}

/// Enables selecting the whole and fractional (to hundredths precision) parts of an HKQuantity value in independent pickers.
struct FractionalQuantityPicker: View {
    enum UsageContext: Equatable {
        /// This picker is one component of a larger multi-component picker (e.g. a schedule item picker).
        case component(availableWidth: CGFloat)

        /// This picker operates independently.
        case independent
    }

    @Binding var whole: Double
    @Binding var fraction: Double
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>
    var usageContext: UsageContext

    private static let wholeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let fractionalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = ""
        formatter.maximumIntegerDigits = 0
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    init(value: Binding<HKQuantity>, unit: HKUnit, guardrail: Guardrail<HKQuantity>, usageContext: UsageContext = .independent) {
        let doubleValue = value.doubleValue(for: unit)
        self._whole = Binding(
            get: { doubleValue.wrappedValue.whole },
            set: { newValue in
                if newValue == guardrail.absoluteBounds.upperBound.doubleValue(for: unit) {
                    doubleValue.wrappedValue = newValue
                } else {
                    doubleValue.wrappedValue = newValue + doubleValue.wrappedValue.fraction
                }
            }
        )
        self._fraction = Binding<Double>(
            get: { doubleValue.wrappedValue.fraction.roundedToHundredths() },
            set: { doubleValue.wrappedValue = doubleValue.wrappedValue.whole + $0 }
        )
        self.unit = unit
        self.guardrail = guardrail
        self.usageContext = usageContext
    }

    var body: some View {
        switch usageContext {
        case .component(availableWidth: let availableWidth):
            return AnyView(body(availableWidth: availableWidth))
        case .independent:
            return AnyView(
                GeometryReader { geometry in
                    HStack {
                        Spacer()
                        self.body(availableWidth: geometry.size.width)
                        Spacer()
                    }
                }
                .frame(height: 216)
            )
        }
    }

    func body(availableWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            QuantityPicker(
                value: $whole.withUnit(unit),
                unit: unit,
                stride: HKQuantity(unit: unit, doubleValue: 1),
                guardrail: guardrail,
                formatter: Self.wholeFormatter,
                isUnitLabelVisible: false
            )
            .frame(width: availableWidth / 3.5)
            .overlay(
                Text(separator)
                    .foregroundColor(Color(.secondaryLabel))
                    .offset(x: spacing + separatorWidth),
                alignment: .trailing
            )
            .padding(.leading, usageContext == .independent ? unitLabelWidth + spacing : 0)
            .padding(.trailing, spacing + separatorWidth + spacing)
            .clipped()

            QuantityPicker(
                value: $fraction.withUnit(unit),
                unit: unit,
                guardrail: fractionalGuardrail,
                selectableValues: selectableFractionValues,
                formatter: Self.fractionalFormatter
            )
            // Ensure fractional picker values update when whole value updates
            .id(whole + fraction)
            .frame(width: availableWidth / 3.5)
            .padding(.trailing, spacing + unitLabelWidth)
            .clipped()
        }
    }

    var fractionalGuardrail: Guardrail<HKQuantity> {
        Guardrail(absoluteBounds: 0...0.99, recommendedBounds: 0...0.99, unit: unit)
    }

    var selectableFractionValues: [Double] {
        whole == guardrail.absoluteBounds.upperBound.doubleValue(for: unit)
            ? [0]
            : fractionalGuardrail.allValues(stridingBy: HKQuantity(unit: unit, doubleValue: 0.01), unit: unit)
    }

    var separator: String { "." }

    var separatorWidth: CGFloat {
        let attributedSeparator = NSAttributedString(
            string: separator,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )

        return attributedSeparator.size().width
    }

    var spacing: CGFloat { 8 }

    var unitLabelWidth: CGFloat {
        let attributedUnitString = NSAttributedString(
            string: unit.shortLocalizedUnitString(),
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )

        return attributedUnitString.size().width
    }
}
