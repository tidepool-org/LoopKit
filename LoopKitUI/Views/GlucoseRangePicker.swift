//
//  GlucoseRangePicker.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


struct GlucoseRangePicker: View {
    @Binding var lowerBound: HKQuantity
    @Binding var upperBound: HKQuantity
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>
    var stride: HKQuantity
    var formatter: NumberFormatter

    init(
        range: Binding<ClosedRange<HKQuantity>>,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        stride: HKQuantity
    ) {
        self._lowerBound = Binding(
            get: { range.wrappedValue.lowerBound},
            set: { range.wrappedValue = $0...range.wrappedValue.upperBound }
        )
        self._upperBound = Binding(
            get: { range.wrappedValue.upperBound },
            set: { range.wrappedValue = range.wrappedValue.lowerBound...$0 }
        )
        self.unit = unit
        self.guardrail = guardrail
        self.stride = stride
        self.formatter = {
            let quantityFormatter = QuantityFormatter()
            quantityFormatter.setPreferredNumberFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                GlucoseValuePicker(
                    value: self.$lowerBound,
                    unit: self.unit,
                    guardrail: self.guardrail,
                    bounds: self.lowerBoundRange,
                    isUnitLabelVisible: false
                )
                // Ensure the selectable picker values update when either bound changes
                .id(self.lowerBound...self.upperBound)
                .frame(width: geometry.size.width / 3.5)
                .overlay(
                    Text(self.separator)
                        .foregroundColor(Color(.secondaryLabel))
                        .offset(x: self.spacing + self.separatorWidth),
                    alignment: .trailing
                )
                .padding(.trailing, self.spacing + self.separatorWidth + self.spacing)
                .clipped()

                GlucoseValuePicker(
                    value: self.$upperBound,
                    unit: self.unit,
                    guardrail: self.guardrail,
                    bounds: self.upperBoundRange
                )
                // Ensure the selectable picker values update when either bound changes
                .id(self.lowerBound...self.upperBound)
                .frame(width: geometry.size.width / 3.5)
                .padding(.trailing, self.spacing + self.unitLabelWidth)
                .clipped()
            }
        }
    }

    var separator: String { "–" }

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

    var lowerBoundRange: ClosedRange<HKQuantity> {
        let min = guardrail.absoluteBounds.lowerBound
        let max = Swift.min(guardrail.absoluteBounds.upperBound, upperBound)
        return min...max
    }

    var upperBoundRange: ClosedRange<HKQuantity> {
        let min = max(guardrail.absoluteBounds.lowerBound, lowerBound)
        let max = guardrail.absoluteBounds.upperBound
        return min...max
    }
}
