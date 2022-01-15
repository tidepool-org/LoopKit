//
//  SyncPumpEvent.swift
//  LoopKit
//
//  Created by Darin Krauss on 12/16/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

public struct SyncPumpEvent: Equatable {
    public let date: Date
    public let type: PumpEventType
    public let alarmType: PumpAlarmType?
    public let mutable: Bool
    public let dose: DoseEntry?
    public let syncIdentifier: String

    public init(date: Date, type: PumpEventType, alarmType: PumpAlarmType? = nil, mutable: Bool, dose: DoseEntry?, syncIdentifier: String) {
        self.date = date
        self.type = type
        self.alarmType = alarmType
        self.mutable = mutable
        self.dose = dose
        self.syncIdentifier = syncIdentifier
    }
}
