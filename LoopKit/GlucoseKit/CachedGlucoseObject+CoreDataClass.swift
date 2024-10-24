//
//  CachedGlucoseObject+CoreDataClass.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData
import HealthKit
import LoopAlgorithm


class CachedGlucoseObject: NSManagedObject {
    var syncVersion: Int? {
        get {
            willAccessValue(forKey: "syncVersion")
            defer { didAccessValue(forKey: "syncVersion") }
            return primitiveSyncVersion?.intValue
        }
        set {
            willChangeValue(forKey: "syncVersion")
            defer { didChangeValue(forKey: "syncVersion") }
            primitiveSyncVersion = newValue.map { NSNumber(value: $0) }
        }
    }
    
    var device: HKDevice? {
        get {
            willAccessValue(forKey: "device")
            defer { didAccessValue(forKey: "device") }
            return primitiveDevice.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKDevice.self, from: $0) }
        }
        set {
            willChangeValue(forKey: "device")
            defer { didChangeValue(forKey: "device") }
            primitiveDevice = newValue.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false) }
        }
    }
    
    var condition: GlucoseCondition? {
        get {
            willAccessValue(forKey: "condition")
            defer { didAccessValue(forKey: "condition") }
            return primitiveCondition.flatMap { GlucoseCondition(rawValue: $0) }
        }
        set {
            willChangeValue(forKey: "condition")
            defer { didChangeValue(forKey: "condition") }
            primitiveCondition = newValue.map { $0.rawValue }
        }
    }

    var trend: GlucoseTrend? {
        get {
            willAccessValue(forKey: "trend")
            defer { didAccessValue(forKey: "trend") }
            return primitiveTrend.flatMap { GlucoseTrend(rawValue: $0.intValue) }
        }
        set {
            willChangeValue(forKey: "trend")
            defer { didChangeValue(forKey: "trend") }
            primitiveTrend = newValue.map { NSNumber(value: $0.rawValue) }
        }
    }

    var hasUpdatedModificationCounter: Bool { changedValues().keys.contains("modificationCounter") }

    func updateModificationCounter() { setPrimitiveValue(managedObjectContext!.modificationCounter!, forKey: "modificationCounter") }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        updateModificationCounter()
    }

    override func willSave() {
        if isUpdated && !hasUpdatedModificationCounter {
            updateModificationCounter()
        }
        super.willSave()
    }
}

// MARK: - Helpers

extension CachedGlucoseObject {
    var quantity: HKQuantity { HKQuantity(unit: HKUnit(from: unitString), doubleValue: value) }

    var quantitySample: HKQuantitySample {
        var metadata: [String: Any] = [:]
        metadata[HKMetadataKeySyncIdentifier] = syncIdentifier
        metadata[HKMetadataKeySyncVersion] = syncVersion
        if isDisplayOnly {
            metadata[MetadataKeyGlucoseIsDisplayOnly] = true
        }
        if wasUserEntered {
            metadata[HKMetadataKeyWasUserEntered] = true
        }
        metadata[MetadataKeyGlucoseCondition] = condition?.rawValue
        metadata[MetadataKeyGlucoseTrend] = trend?.symbol
        metadata[MetadataKeyGlucoseTrendRateValue] = trendRateValue

        return HKQuantitySample(
            type: HealthKitSampleStore.glucoseType,
            quantity: quantity,
            start: startDate,
            end: startDate,
            device: device,
            metadata: metadata
        )
    }

    var trendRate: HKQuantity? {
        get {
            guard let trendRateValue = trendRateValue else {
                return nil
            }
            return HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: trendRateValue.doubleValue)
        }

        set {
            if let newValue = newValue {
                let unit = HKUnit(from: unitString).unitDivided(by: .minute())
                trendRateValue = NSNumber(value: newValue.doubleValue(for: unit))
            } else {
                trendRateValue = nil
            }
        }
    }
}

// MARK: - Operations

extension CachedGlucoseObject {

    /// Creates (initializes) a `CachedGlucoseObject` from a new CGM sample from Loop.
    /// - parameters:
    ///   - sample: A new glucose (CGM) sample to copy data from.
    ///   - provenanceIdentifier: A string uniquely identifying the provenance (origin) of the sample.
    ///   - healthKitStorageDelay: The amount of time (seconds) to delay writing this sample to HealthKit.  A `nil` here means this sample is not eligible (i.e. authorized) to be written to HealthKit. Note that user entered glucose samples are sent directly to HealthKit without any delay
    func create(from sample: NewGlucoseSample, provenanceIdentifier: String, healthKitStorageDelay: TimeInterval?) {
        self.uuid = nil
        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = sample.syncIdentifier
        self.syncVersion = sample.syncVersion
        self.value = sample.quantity.doubleValue(for: .milligramsPerDeciliter)
        self.unitString = HKUnit.milligramsPerDeciliter.unitString
        self.startDate = sample.date
        self.isDisplayOnly = sample.isDisplayOnly
        self.wasUserEntered = sample.wasUserEntered
        self.device = sample.device
        self.condition = sample.condition
        self.trend = sample.trend
        self.trendRate = sample.trendRate
        self.healthKitEligibleDate = (healthKitStorageDelay != nil && sample.wasUserEntered) ? sample.date : healthKitStorageDelay.map { sample.date.addingTimeInterval($0) }
    }

    // HealthKit
    func create(from sample: HKQuantitySample) {
        self.uuid = sample.uuid
        self.provenanceIdentifier = sample.provenanceIdentifier
        self.syncIdentifier = sample.syncIdentifier
        self.syncVersion = sample.syncVersion
        self.value = sample.quantity.doubleValue(for: .milligramsPerDeciliter)
        self.unitString = HKUnit.milligramsPerDeciliter.unitString
        self.startDate = sample.startDate
        self.isDisplayOnly = sample.isDisplayOnly
        self.wasUserEntered = sample.wasUserEntered
        self.device = sample.device
        self.condition = sample.condition
        self.trend = sample.trend
        self.trendRate = sample.trendRate
        // The assumption here is that if this is created from a HKQuantitySample, it is coming out of HealthKit, and
        // therefore does not need to be written to HealthKit.
        self.healthKitEligibleDate = nil
    }
}

// MARK: - Watch Synchronization

extension CachedGlucoseObject {
    func update(from sample: StoredGlucoseSample) {
        self.uuid = sample.uuid
        self.provenanceIdentifier = sample.provenanceIdentifier
        self.syncIdentifier = sample.syncIdentifier
        self.syncVersion = sample.syncVersion
        self.value = sample.quantity.doubleValue(for: .milligramsPerDeciliter)
        self.unitString = HKUnit.milligramsPerDeciliter.unitString
        self.startDate = sample.startDate
        self.isDisplayOnly = sample.isDisplayOnly
        self.wasUserEntered = sample.wasUserEntered
        self.device = sample.device
        self.condition = sample.condition
        self.trend = sample.trend
        self.trendRate = sample.trendRate
        self.healthKitEligibleDate = sample.healthKitEligibleDate
    }
}
