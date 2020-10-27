//
//  DoseEntry+LocalizedDescription.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-10-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

extension DoseEntry {
    static var units = HKUnit.internationalUnit()

    private var numberFormatter: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = DoseEntry.unitsPerHour.maxFractionDigits
        return numberFormatter
    }

    public var localizedAttributedDescription: NSAttributedString {
        let typeAndUnitAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.secondaryLabel
        ]

        switch type {
        case .basal, .bolus, .tempBasal:
            let unitString = type == .bolus ? DoseEntry.units.shortLocalizedUnitString() : DoseEntry.unitsPerHour.shortLocalizedUnitString()
            let value: Double = type == .bolus ? (deliveredUnits ?? programmedUnits) : unitsPerHour
            
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .headline),
                .foregroundColor: UIColor.label
            ]
             
            let typeAttributedString = NSAttributedString(string: type.localizedDescription + ": ", attributes: typeAndUnitAttributes)
            let valueAttributedString = NSAttributedString(string: (numberFormatter.string(from: value) ?? "?") + " ", attributes: valueAttributes)
            let unitAttributedString = NSAttributedString(string: unitString, attributes: typeAndUnitAttributes)

            let tempBasalAttributedDescription = NSMutableAttributedString()
            tempBasalAttributedDescription.append(typeAttributedString)
            tempBasalAttributedDescription.append(valueAttributedString)
            tempBasalAttributedDescription.append(unitAttributedString)
            return tempBasalAttributedDescription
        case .suspend, .resume:
            return NSAttributedString(string: type.localizedDescription, attributes: typeAndUnitAttributes)
        }
    }
}
