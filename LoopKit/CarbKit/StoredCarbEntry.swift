//
//  StoredCarbEntry.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/22/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit
import CoreData
import LoopAlgorithm

public struct StoredCarbEntry: CarbEntry, Equatable {

    public let uuid: UUID?

    public static let defaultProvenanceIdentifier = "com.LoopKit.Loop"

    // MARK: - HealthKit Sync Support

    public let provenanceIdentifier: String
    public let syncIdentifier: String?
    public let syncVersion: Int?

    // MARK: - SampleValue

    public let startDate: Date
    public let quantity: HKQuantity

    // MARK: - CarbEntry

    public let foodType: String?
    public let absorptionTime: TimeInterval?
    public let favoriteFoodID: String?
    public let createdByCurrentApp: Bool

    // MARK: - User dates

    public let userCreatedDate: Date?
    public let userUpdatedDate: Date?

    public init(
        startDate: Date,
        quantity: HKQuantity,
        uuid: UUID? = nil,
        provenanceIdentifier: String = Self.defaultProvenanceIdentifier,
        syncIdentifier: String? = nil,
        syncVersion: Int? = nil,
        foodType: String? = nil,
        absorptionTime: TimeInterval? = nil,
        favoriteFoodID: String? = nil,
        createdByCurrentApp: Bool = true,
        userCreatedDate: Date? = nil,
        userUpdatedDate: Date? = nil
    ) {
        self.uuid = uuid
        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.startDate = startDate
        self.quantity = quantity
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.favoriteFoodID = favoriteFoodID
        self.createdByCurrentApp = createdByCurrentApp
        self.userCreatedDate = userCreatedDate
        self.userUpdatedDate = userUpdatedDate
    }

    public var amount: Double {
        quantity.doubleValue(for: .gram())
    }
}

extension StoredCarbEntry {
    init(managedObject: CachedCarbObject) {
        self.init(
            startDate: managedObject.startDate,
            quantity: managedObject.quantity,
            uuid: managedObject.uuid,
            provenanceIdentifier: managedObject.provenanceIdentifier,
            syncIdentifier: managedObject.syncIdentifier,
            syncVersion: managedObject.syncVersion,
            foodType: managedObject.foodType,
            absorptionTime: managedObject.absorptionTime,
            favoriteFoodID: managedObject.quantitySample.favoriteFoodID,
            createdByCurrentApp: managedObject.createdByCurrentApp,
            userCreatedDate: managedObject.userCreatedDate,
            userUpdatedDate: managedObject.userUpdatedDate
        )
    }
}

extension StoredCarbEntry: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            startDate: try container.decode(Date.self, forKey: .startDate),
            quantity: HKQuantity(unit: .gram(), doubleValue: try container.decode(Double.self, forKey: .quantity)),
            uuid: try container.decodeIfPresent(UUID.self, forKey: .uuid),
            provenanceIdentifier: (try container.decodeIfPresent(String.self, forKey: .provenanceIdentifier)) ?? Self.defaultProvenanceIdentifier,
            syncIdentifier: try container.decodeIfPresent(String.self, forKey: .syncIdentifier),
            syncVersion: try container.decodeIfPresent(Int.self, forKey: .syncVersion),
            foodType: try container.decodeIfPresent(String.self, forKey: .foodType),
            absorptionTime: try container.decodeIfPresent(TimeInterval.self, forKey: .absorptionTime),
            createdByCurrentApp: (try container.decodeIfPresent(Bool.self, forKey: .createdByCurrentApp)) ?? true,
            userCreatedDate: try container.decodeIfPresent(Date.self, forKey: .userCreatedDate),
            userUpdatedDate: try container.decodeIfPresent(Date.self, forKey: .userUpdatedDate)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(uuid, forKey: .uuid)
        if provenanceIdentifier != Self.defaultProvenanceIdentifier {
            try container.encode(provenanceIdentifier, forKey: .provenanceIdentifier)
        }
        try container.encodeIfPresent(syncIdentifier, forKey: .syncIdentifier)
        try container.encodeIfPresent(syncVersion, forKey: .syncVersion)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(quantity.doubleValue(for: .gram()), forKey: .quantity)
        try container.encodeIfPresent(foodType, forKey: .foodType)
        try container.encodeIfPresent(absorptionTime, forKey: .absorptionTime)
        if !createdByCurrentApp {
            try container.encode(createdByCurrentApp, forKey: .createdByCurrentApp)
        }
        try container.encodeIfPresent(userCreatedDate, forKey: .userCreatedDate)
        try container.encodeIfPresent(userUpdatedDate, forKey: .userUpdatedDate)
    }
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case provenanceIdentifier
        case syncIdentifier
        case syncVersion
        case startDate
        case quantity
        case foodType
        case absorptionTime
        case createdByCurrentApp
        case userCreatedDate
        case userUpdatedDate
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

        var syncIdentifier: String?
        var syncVersion: Int?

        if let externalID = rawValue["externalId"] as? String {
            syncIdentifier = externalID
            syncVersion = 1
        }

        self.init(
            startDate: startDate,
            quantity: HKQuantity(unit: HKUnit(from: unitString), doubleValue: value),
            uuid: uuid,
            provenanceIdentifier: createdByCurrentApp ? HKSource.default().bundleIdentifier : "",
            syncIdentifier: syncIdentifier,
            syncVersion: syncVersion,
            foodType: rawValue["foodType"] as? String,
            absorptionTime: rawValue["absorptionTime"] as? TimeInterval,
            createdByCurrentApp: createdByCurrentApp,
            userCreatedDate: nil,
            userUpdatedDate: nil
        )
    }
}
