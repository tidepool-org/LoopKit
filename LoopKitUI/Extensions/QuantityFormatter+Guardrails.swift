//
//  QuantityFormatter+Guardrails.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 11/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit

fileprivate let mgdLFormatter = QuantityFormatter()
fileprivate let mmolLFormatter: QuantityFormatter = {
    let result = QuantityFormatter()
    result.numberFormatter.maximumFractionDigits = 1
    return result
}()

extension HKQuantity {
    // TODO: pass in preferredUnit instead of having both units.
    var bothUnitsString: String {
        String(format: "%1$@ (%2$@)",
               mgdLFormatter.string(from: self, for: .milligramsPerDeciliter)!,
               mmolLFormatter.string(from: self, for: .millimolesPerLiter)!)
    }

    public func stringForGlucoseUnit(_ glucoseUnit: HKUnit) -> String {
        if glucoseUnit == HKUnit.milligramsPerDeciliter {
            return mgdLFormatter.string(from: self, for: .milligramsPerDeciliter)!
        } else {
            return mmolLFormatter.string(from: self, for: .millimolesPerLiter)!
        }
    }
}

extension ClosedRange where Bound == HKQuantity {
    public func stringForGlucoseUnit(_ glucoseUnit: HKUnit) -> String {
        let formatter: QuantityFormatter
        if glucoseUnit == HKUnit.milligramsPerDeciliter {
            formatter = mgdLFormatter
        } else {
            formatter = mmolLFormatter
        }
        return String(format: "%1$@-%2$@",
                      formatter.string(from: self.lowerBound, for: glucoseUnit, includeUnit: false)!,
                      formatter.string(from: self.upperBound, for: glucoseUnit, includeUnit: true)!)
    }
}
