//
//  GuardrailExtensions.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit

public extension Guardrail where Value == HKQuantity {
    static func basalRate(supportedBasalRates: [Double]) -> Guardrail {
        return Guardrail (
            absoluteBounds: supportedBasalRates.first!...supportedBasalRates.last!,
            recommendedBounds: supportedBasalRates.dropFirst().first!...supportedBasalRates.last!,
            unit: .internationalUnitsPerHour
        )
    }
    
    static var recommendedMaximumScheduledBasalScaleFactor: Double {
        return 6
    }
    
    static func maximumBasalRate(supportedBasalRates: [Double], scheduledBasalRange: ClosedRange<Double>?) -> Guardrail {
        let minimumSupportedBasalRate = supportedBasalRates.first!
        let recommendedLowerBound = minimumSupportedBasalRate == 0 ? supportedBasalRates.dropFirst().first! : minimumSupportedBasalRate
        let recommendedUpperBound: Double
        if let maximumScheduledBasalRate = scheduledBasalRange?.upperBound {
            recommendedUpperBound = maximumScheduledBasalRate == 0
                ? recommendedLowerBound
                : recommendedMaximumScheduledBasalScaleFactor * maximumScheduledBasalRate
        } else {
            recommendedUpperBound = supportedBasalRates.last!
        }
        return Guardrail(
            absoluteBounds: supportedBasalRates.first!...supportedBasalRates.last!,
            recommendedBounds: recommendedLowerBound...recommendedUpperBound,
            unit: .internationalUnitsPerHour
        )
    }
}
