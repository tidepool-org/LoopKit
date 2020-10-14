//
//  SyncGlucoseObject.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct SyncGlucoseObject: Codable, Equatable {
    public let uuid: UUID?
    public let provenanceIdentifier: String
    public let syncIdentifier: String?
    public let syncVersion: Int?
    public let value: Double
    public let unitString: String
    public let startDate: Date
    public let isDisplayOnly: Bool
    public let wasUserEntered: Bool

    public init(uuid: UUID?,
                provenanceIdentifier: String,
                syncIdentifier: String?,
                syncVersion: Int?,
                value: Double,
                unitString: String,
                startDate: Date,
                isDisplayOnly: Bool,
                wasUserEntered: Bool) {
        self.uuid = uuid
        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.value = value
        self.unitString = unitString
        self.startDate = startDate
        self.isDisplayOnly = isDisplayOnly
        self.wasUserEntered = wasUserEntered
    }

    public var quantity: HKQuantity { HKQuantity(unit: HKUnit(from: unitString), doubleValue: value) }
}

extension SyncGlucoseObject {
    init(managedObject: CachedGlucoseObject) {
        self.init(uuid: managedObject.uuid,
                  provenanceIdentifier: managedObject.provenanceIdentifier,
                  syncIdentifier: managedObject.syncIdentifier,
                  syncVersion: managedObject.syncVersion,
                  value: managedObject.value,
                  unitString: managedObject.unitString,
                  startDate: managedObject.startDate,
                  isDisplayOnly: managedObject.isDisplayOnly,
                  wasUserEntered: managedObject.wasUserEntered)
    }
}
