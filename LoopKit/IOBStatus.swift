//
//  IOBStatus.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


public struct IOBStatus {
    public let timestamp: Date
    public let iob: Double?         // basal iob + bolus iob: can be negative
    public let basalIOB: Double?    // does not include bolus iob

    public init(timestamp: Date, iob: Double? = nil, basalIOB: Double? = nil) {
        self.timestamp = timestamp
        self.iob = iob
        self.basalIOB = basalIOB
    }
}
