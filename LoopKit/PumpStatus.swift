//
//  PumpStatus.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


public struct PumpStatus {
    public let clock: Date
    public let pumpID: String
    public let iob: IOBStatus?
    public let battery: BatteryStatus?
    public let suspended: Bool?
    public let bolusing: Bool?
    public let reservoir: Double?
    public let secondsFromGMT: Int?

    public init(clock: Date, pumpID: String, iob: IOBStatus? = nil, battery: BatteryStatus? = nil, suspended: Bool? = nil, bolusing: Bool? = nil, reservoir: Double? = nil, secondsFromGMT: Int? = nil) {
        self.clock = clock
        self.pumpID = pumpID
        self.iob = iob
        self.battery = battery
        self.suspended = suspended
        self.bolusing = bolusing
        self.reservoir = reservoir
        self.secondsFromGMT = secondsFromGMT
    }
}
