//
//  CarbEntry.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/3/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit


public protocol CarbEntry: SampleValue {
    var absorptionTime: TimeInterval? { get }
}

public struct AnyCarbEntry: CarbEntry {
    public var startDate: Date
    public var quantity: HKQuantity
    public var absorptionTime: TimeInterval?

    public init(startDate: Date, quantity: HKQuantity, absorptionTime: TimeInterval?) {
        self.startDate = startDate
        self.quantity = quantity
        self.absorptionTime = absorptionTime
    }

    public init<Entry: CarbEntry>(_ entry: Entry) {
        self.init(startDate: entry.startDate, quantity: entry.quantity, absorptionTime: entry.absorptionTime)
    }
}
