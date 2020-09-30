//
//  NSNumberFormatter.swift
//  Loop
//
//  Created by Nate Racklyeft on 9/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


extension NumberFormatter {
    func string(from number: Double) -> String? {
        return string(from: NSNumber(value: number))
    }

    func string(from number: Double, unit: String?, style: Formatter.UnitStyle = .medium) -> String? {
        guard let stringValue = string(from: number) else {
            return nil
        }

        let format: String
        guard let unit = unit else {
            format = LocalizedString(
                "quantity-no-unit",
                value: "%1$@",
                comment: "Format string for localized numeric value without any unit. (1: numeric value)"
            )
            return String(
                format: format,
                stringValue
            )
        }
        
        switch style {
        case .long, .medium:
            format = LocalizedString(
                "quantity-and-unit-space",
                value: "%1$@ %2$@",
                comment: "Format string for combining localized numeric value and unit with a space. (1: numeric value)(2: unit)"
            )
        case .short:
            fallthrough
        @unknown default:
            format = LocalizedString(
                "quantity-and-unit-tight",
                value: "%1$@%2$@",
                comment: "Format string for combining localized numeric value and unit without spacing. (1: numeric value)(2: unit)"
            )
        }

        return String(
            format: format,
            stringValue,
            unit
        )
    }
}
