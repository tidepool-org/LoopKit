//
//  BatteryStatus.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


public enum BatteryIndicator: String {
    case low = "low"
    case normal = "normal"
}


public struct BatteryStatus {
    public let percent: Int?
    public let voltage: Double?
    public let status: BatteryIndicator?

    public init(percent: Int? = nil, voltage: Double? = nil, status: BatteryIndicator? = nil) {
        self.percent = percent
        self.voltage = voltage
        self.status = status
    }
}
