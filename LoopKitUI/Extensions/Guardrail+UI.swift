//
//  Guardrail+UI.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


extension Guardrail where Value == HKQuantity {
    func color(for quantity: HKQuantity,
               inRangeColor inRange: Color = .primary,
               warningColor warning: Color = .warning,
               criticalColor critical: Color = .critical) -> Color {
        switch classification(for: quantity) {
        case .withinRecommendedRange:
            return inRange
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return critical
            case .belowRecommended, .aboveRecommended:
                return warning
            }
        }
    }
}
