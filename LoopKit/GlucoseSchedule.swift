//
//  GlucoseSchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit

public typealias GlucoseSchedule = SingleQuantitySchedule

public typealias InsulinSensitivitySchedule = GlucoseSchedule

public extension InsulinSensitivitySchedule {
    init?(sensitivityUnit: HKUnit, dailyItems: [RepeatingScheduleValue<T>], timeZone: TimeZone? = nil) {
        precondition(sensitivityUnit == HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit()) ||
                        sensitivityUnit == HKUnit.millimolesPerLiter.unitDivided(by: .internationalUnit()))
        self.init(unit: sensitivityUnit, dailyItems: dailyItems, timeZone: timeZone)
    }

    // TODO is this being used?
    func convertTo(unit: HKUnit) -> InsulinSensitivitySchedule? {
        guard unit != self.unit else {
            return self
        }

        let convertedDailyItems: [RepeatingScheduleValue<Double>] = self.items.map {
            RepeatingScheduleValue(startTime: $0.startTime,
                                   value: HKQuantity(unit: self.unit, doubleValue: $0.value).doubleValue(for: unit)
            )
        }

        return InsulinSensitivitySchedule(unit: unit,
                                          dailyItems: convertedDailyItems,
                                          timeZone: timeZone)
    }

    // TODO replace by new `quantities` in `DailyQuantitySchedule`
    func schedule(for glucoseUnit: HKUnit) -> InsulinSensitivitySchedule? {
        // InsulinSensitivitySchedule stores only the glucose unit.
        precondition(glucoseUnit == .millimolesPerLiter ||
                        glucoseUnit == .milligramsPerDeciliter)
        return self.convertTo(unit: glucoseUnit)
    }
}
