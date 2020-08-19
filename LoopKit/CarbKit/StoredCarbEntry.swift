//
//  StoredCarbEntry.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/22/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit
import CoreData

public struct StoredCarbEntry: CarbEntry, Equatable {

    public let uuid: UUID?

    // MARK: - HealthKit Sync Support

    public let provenanceIdentifier: String?
    public let syncIdentifier: String?
    public let syncVersion: Int?

    // MARK: - SampleValue

    public let startDate: Date
    public let quantity: HKQuantity

    // MARK: - CarbEntry

    public let foodType: String?
    public let absorptionTime: TimeInterval?
    public let createdByCurrentApp: Bool

    // MARK: - DEPRECATED - Sync state

    public let externalID: String?

    // MARK: - User dates

    public let userCreatedDate: Date?
    public let userUpdatedDate: Date?

    public init(
        uuid: UUID?,
        provenanceIdentifier: String?,
        syncIdentifier: String?,
        syncVersion: Int?,
        startDate: Date,
        quantity: HKQuantity,
        foodType: String?,
        absorptionTime: TimeInterval?,
        createdByCurrentApp: Bool,
        externalID: String?,
        userCreatedDate: Date?,
        userUpdatedDate: Date?
    ) {
        self.uuid = uuid
        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.startDate = startDate
        self.quantity = quantity
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.createdByCurrentApp = createdByCurrentApp
        self.externalID = externalID
        self.userCreatedDate = userCreatedDate
        self.userUpdatedDate = userUpdatedDate
    }
}

extension StoredCarbEntry {
    init(managedObject: CachedCarbObject) {
        self.init(
            uuid: managedObject.uuid,
            provenanceIdentifier: managedObject.provenanceIdentifier,
            syncIdentifier: managedObject.syncIdentifier,
            syncVersion: managedObject.syncVersion,
            startDate: managedObject.startDate,
            quantity: managedObject.quantity,
            foodType: managedObject.foodType,
            absorptionTime: managedObject.absorptionTime,
            createdByCurrentApp: managedObject.createdByCurrentApp,
            externalID: managedObject.externalID,
            userCreatedDate: managedObject.userCreatedDate,
            userUpdatedDate: managedObject.userUpdatedDate
        )
    }
}

// MARK: - DEPRECATED - Used only for migration

extension StoredCarbEntry {
    typealias RawValue = [String: Any]

    init?(rawValue: RawValue) {
        guard let
            sampleUUIDString = rawValue["sampleUUID"] as? String,
            let uuid = UUID(uuidString: sampleUUIDString),
            let startDate = rawValue["startDate"] as? Date,
            let unitString = rawValue["unitString"] as? String,
            let value = rawValue["value"] as? Double,
            let createdByCurrentApp = rawValue["createdByCurrentApp"] as? Bool else
        {
            return nil
        }

        self.init(
            uuid: uuid,
            provenanceIdentifier: nil,
            syncIdentifier: nil,
            syncVersion: nil,
            startDate: startDate,
            quantity: HKQuantity(unit: HKUnit(from: unitString), doubleValue: value),
            foodType: rawValue["foodType"] as? String,
            absorptionTime: rawValue["absorptionTime"] as? TimeInterval,
            createdByCurrentApp: createdByCurrentApp,
            externalID: rawValue["externalId"] as? String,
            userCreatedDate: nil,
            userUpdatedDate: nil
        )
    }
}
