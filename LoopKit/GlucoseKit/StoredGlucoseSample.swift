//
//  StoredGlucoseSample.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct StoredGlucoseSample: GlucoseSampleValue, Equatable {
    public let uuid: UUID?  // Note this is the UUID from HealthKit.  Nil if not (yet) stored in HealthKit.

    // MARK: - HealthKit Sync Support

    public let provenanceIdentifier: String
    public let syncIdentifier: String?
    public let syncVersion: Int?
    public let device: HKDevice?
    public let healthKitEligibleDate: Date?

    // MARK: - SampleValue

    public let startDate: Date
    public let quantity: HKQuantity

    // MARK: - GlucoseSampleValue

    public let isDisplayOnly: Bool
    public let wasUserEntered: Bool
    public let condition: GlucoseCondition?
    public let trend: GlucoseTrend?
    public let trendRate: HKQuantity?

    public init(sample: HKQuantitySample) {
        self.init(
            uuid: sample.uuid,
            provenanceIdentifier: sample.provenanceIdentifier,
            syncIdentifier: sample.syncIdentifier,
            syncVersion: sample.syncVersion,
            startDate: sample.startDate,
            quantity: sample.quantity,
            condition: sample.condition,
            trend: sample.trend,
            trendRate: sample.trendRate,
            isDisplayOnly: sample.isDisplayOnly,
            wasUserEntered: sample.wasUserEntered,
            device: sample.device,
            healthKitEligibleDate: nil)
    }

    public init(
        uuid: UUID?,
        provenanceIdentifier: String,
        syncIdentifier: String?,
        syncVersion: Int?,
        startDate: Date,
        quantity: HKQuantity,
        condition: GlucoseCondition?,
        trend: GlucoseTrend?,
        trendRate: HKQuantity?,
        isDisplayOnly: Bool,
        wasUserEntered: Bool,
        device: HKDevice?,
        healthKitEligibleDate: Date?) {
        self.uuid = uuid
        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.startDate = startDate
        self.quantity = quantity
        self.condition = condition
        self.trend = trend
        self.trendRate = trendRate
        self.isDisplayOnly = isDisplayOnly
        self.wasUserEntered = wasUserEntered
        self.device = device
        self.healthKitEligibleDate = healthKitEligibleDate
    }
}

extension StoredGlucoseSample {
    init(managedObject: CachedGlucoseObject) {
        self.init(
            uuid: managedObject.uuid,
            provenanceIdentifier: managedObject.provenanceIdentifier,
            syncIdentifier: managedObject.syncIdentifier,
            syncVersion: managedObject.syncVersion,
            startDate: managedObject.startDate,
            quantity: managedObject.quantity,
            condition: managedObject.condition,
            trend: managedObject.trend,
            trendRate: managedObject.trendRate,
            isDisplayOnly: managedObject.isDisplayOnly,
            wasUserEntered: managedObject.wasUserEntered,
            device: managedObject.device,
            healthKitEligibleDate: managedObject.healthKitEligibleDate)
    }
}
