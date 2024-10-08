//
//  GlucoseStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData
import HealthKit
import os.log
import LoopAlgorithm

public protocol GlucoseStoreDelegate: AnyObject {

    /**
     Informs the delegate that the glucose store has updated glucose data.

     - Parameter glucoseStore: The glucose store that has updated glucose data.
     */
    func glucoseStoreHasUpdatedGlucoseData(_ glucoseStore: GlucoseStore)

}

/**
 Manages storage, retrieval, and calculation of glucose data.

 There are three tiers of storage:

 * Persistant cache, stored in Core Data, used to ensure access if the app is suspended and re-launched while the Health database
 * is protected and to provide data for upload to remote data services. Backfilled from HealthKit data up to observation interval.
```
 0    [max(cacheLength, momentumDataInterval, observationInterval)]
 |––––|
```
 * HealthKit data, managed by the current application
```
 0    [managedDataInterval?]
 |––––––––––––|
```
 * HealthKit data, managed by the manufacturer's application
```
      [managedDataInterval?]           [maxPurgeInterval]
              |–––––––––--->
```
 */
public final class GlucoseStore {

    /// Notification posted when glucose samples were changed, either via direct add or from HealthKit
    public static let glucoseSamplesDidChange = NSNotification.Name(rawValue: "com.loopkit.GlucoseStore.glucoseSamplesDidChange")

    public weak var delegate: GlucoseStoreDelegate?

    /// Current date. Will return the unit-test configured date if set, or the current date otherwise.
    internal var currentDate: Date {
        test_currentDate ?? Date()
    }

    /// Allows for controlling uses of the system date in unit testing
    internal var test_currentDate: Date?

    internal func currentDate(timeIntervalSinceNow: TimeInterval = 0) -> Date {
        return currentDate.addingTimeInterval(timeIntervalSinceNow)
    }

    public let hkSampleStore: HealthKitSampleStore?

    /// The oldest interval to include when purging managed data
    private let maxPurgeInterval: TimeInterval = TimeInterval(hours: 24) * 7

    /// The interval before which glucose values should be purged from HealthKit. If nil, glucose values are not purged.
    public var managedDataInterval: TimeInterval? {
        get {
            return lockedManagedDataInterval.value
        }
        set {
            lockedManagedDataInterval.value = newValue
        }
    }
    private let lockedManagedDataInterval = Locked<TimeInterval?>(nil)

    /// The interval of glucose data to keep in cache
    public let cacheLength: TimeInterval

    /// The interval of glucose data to use for momentum calculation
    public let momentumDataInterval: TimeInterval

    private let queue = DispatchQueue(label: "com.loopkit.GlucoseStore.queue", qos: .utility)

    private let log = OSLog(category: "GlucoseStore")

    /// The most-recent glucose value.
    public private(set) var latestGlucose: GlucoseSampleValue? {
        get {
            return lockedLatestGlucose.value
        }
        set {
            lockedLatestGlucose.value = newValue
        }
    }
    private let lockedLatestGlucose = Locked<GlucoseSampleValue?>(nil)

    private let cacheStore: PersistenceController

    private let provenanceIdentifier: String

    public var healthKitStorageDelay: TimeInterval = 0

    // If HealthKit sharing is not authorized, `nil` will prevent later storage
    var healthKitStorageDelayIfAllowed: TimeInterval? {
        guard let hkSampleStore, hkSampleStore.sharingAuthorized else {
            return nil
        }
        return healthKitStorageDelay
    }
    
    static let healthKitQueryAnchorMetadataKey = "com.loopkit.GlucoseStore.hkQueryAnchor"

    public init(
        healthKitSampleStore: HealthKitSampleStore? = nil,
        cacheStore: PersistenceController,
        cacheLength: TimeInterval = 60 /* minutes */ * 60 /* seconds */,
        momentumDataInterval: TimeInterval = GlucoseMath.momentumDataInterval,
        provenanceIdentifier: String = HKSource.default().bundleIdentifier
    ) async {
        let cacheLength = max(cacheLength, momentumDataInterval)

        self.cacheStore = cacheStore
        self.momentumDataInterval = momentumDataInterval
        self.cacheLength = cacheLength
        self.provenanceIdentifier = provenanceIdentifier
        self.hkSampleStore = healthKitSampleStore

        healthKitSampleStore?.delegate = self

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
                cacheStore.onReady { (error) in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            let anchor = await cacheStore.fetchAnchor(key: GlucoseStore.healthKitQueryAnchorMetadataKey)
            self.hkSampleStore?.setInitialQueryAnchor(anchor)
            await self.updateLatestGlucose()
        } catch {
            log.error("CacheStore initialization failed: %{public}@", String(describing: error))
        }
    }
}

// MARK: - HKSampleStoreCompositionalDelegate
extension GlucoseStore: HealthKitSampleStoreDelegate {

    public func storeQueryAnchor(_ anchor: HKQueryAnchor) {
        cacheStore.storeAnchor(anchor, key: GlucoseStore.healthKitQueryAnchorMetadataKey)
    }

    public func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], anchor: HKQueryAnchor, completion: @escaping (Bool) -> Void) {
        queue.async {
            var changed = false
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    // Add new samples
                    if let samples = added as? [HKQuantitySample] {
                        for sample in samples {
                            if try self.addGlucoseSample(for: sample) {
                                self.log.debug("Saved sample %@ into cache from HKAnchoredObjectQuery", sample.uuid.uuidString)
                                changed = true
                            } else {
                                self.log.default("Sample %@ from HKAnchoredObjectQuery already present in cache", sample.uuid.uuidString)
                            }
                        }
                    }

                    // Delete deleted samples
                    let count = try self.deleteGlucoseSamples(withUUIDs: deleted.map { $0.uuid })
                    if count > 0 {
                        self.log.debug("Deleted %d samples from cache from HKAnchoredObjectQuery", count)
                        changed = true
                    }

                    guard changed else {
                        return
                    }

                    error = self.cacheStore.save()
                } catch let coreDataError {
                    error = coreDataError
                }
            }

            guard error == nil else {
                completion(false)
                return
            }

            if !changed {
                completion(true)
                return
            }

            // Purge expired managed data from HealthKit
            if let newestStartDate = added.map({ $0.startDate }).max() {
                self.purgeExpiredManagedDataFromHealthKit(before: newestStartDate)
            }

            Task {
                await self.handleUpdatedGlucoseData()
            }
            completion(true)
        }
    }
}

// MARK: - Fetching

extension GlucoseStore {

    /// Retrieves glucose samples within the specified date range.
    ///
    /// - Parameters:
    ///   - start: The earliest date of glucose samples to retrieve, if provided.
    ///   - end: The latest date of glucose samples to retrieve, if provided.
    ///   - returns: An array of glucose samples, in chronological order by startDate, or error.
    public func getGlucoseSamples(start: Date? = nil, end: Date? = nil) async throws -> [StoredGlucoseSample] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let result = self.getGlucoseSamples(start: start, end: end)
                switch result {
                case .success(let samples):
                    continuation.resume(returning: samples)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Retrieves glucose samples within the specified date range.
    ///
    /// - Parameters:
    ///   - start: The earliest date of glucose samples to retrieve, if provided.
    ///   - end: The latest date of glucose samples to retrieve, if provided.
    ///   - completion: A closure called once the glucose samples have been retrieved.
    ///   - result: An array of glucose samples, in chronological order by startDate, or error.
    public func getGlucoseSamples(start: Date? = nil, end: Date? = nil, completion: @escaping (_ result: Result<[StoredGlucoseSample], Error>) -> Void) {
        queue.async {
            completion(self.getGlucoseSamples(start: start, end: end))
        }
    }

    private func getGlucoseSamples(start: Date? = nil, end: Date? = nil) -> Result<[StoredGlucoseSample], Error> {
        dispatchPrecondition(condition: .onQueue(queue))

        var samples: [StoredGlucoseSample] = []
        var error: Error?

        cacheStore.managedObjectContext.performAndWait {
            do {
                samples = try self.getCachedGlucoseObjects(start: start, end: end).map { StoredGlucoseSample(managedObject: $0) }
            } catch let coreDataError {
                error = coreDataError
            }
        }

        if let error = error {
            return .failure(error)
        }

        return .success(samples)
    }

    private func getCachedGlucoseObjects(start: Date? = nil, end: Date? = nil) throws -> [CachedGlucoseObject] {
        dispatchPrecondition(condition: .onQueue(queue))

        var predicates: [NSPredicate] = []
        if let start = start {
            predicates.append(NSPredicate(format: "startDate >= %@", start as NSDate))
        }
        if let end = end {
            predicates.append(NSPredicate(format: "startDate < %@", end as NSDate))
        }

        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
        request.predicate = (predicates.count > 1) ? NSCompoundPredicate(andPredicateWithSubpredicates: predicates) : predicates.first
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        return try self.cacheStore.managedObjectContext.fetch(request)
    }

    private func updateLatestGlucose() async {
        do {
            let latestGlucose = try await cacheStore.managedObjectContext.perform {
                let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
                request.fetchLimit = 1

                let objects = try self.cacheStore.managedObjectContext.fetch(request)
                return objects.first.map { StoredGlucoseSample(managedObject: $0) }
            }
            queue.sync {
                self.latestGlucose = latestGlucose
            }
        } catch {
            self.log.error("Unable to fetch latest glucose object: %{public}@", String(describing: error))
        }
    }
}

// MARK: - Modification

extension GlucoseStore {
    /// Add glucose samples to store.
    ///
    /// - Parameters:
    ///   - samples: The new glucose samples to add to the store.
    ///   - returns: An array of glucose samples that were stored.
    public func addGlucoseSamples(_ samples: [NewGlucoseSample]) async throws -> [StoredGlucoseSample] {
        guard !samples.isEmpty else {
            return []
        }

        let storedSamples: [StoredGlucoseSample] = try await self.cacheStore.managedObjectContext.perform {
            // Filter samples to ensure no duplicate sync identifiers nor existing sample with matching sync identifier for our provenance identifier
            var syncIdentifiers = Set<String>()
            let samples: [NewGlucoseSample] = try samples.compactMap { sample in
                guard syncIdentifiers.insert(sample.syncIdentifier).inserted else {
                    self.log.default("Skipping adding glucose sample due to duplicate sync identifier: %{public}@", sample.syncIdentifier)
                    return nil
                }

                let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "provenanceIdentifier == %@", self.provenanceIdentifier),
                                                                                        NSPredicate(format: "syncIdentifier == %@", sample.syncIdentifier)])
                request.fetchLimit = 1

                guard try self.cacheStore.managedObjectContext.count(for: request) == 0 else {
                    self.log.default("Skipping adding glucose sample due to existing cached sync identifier: %{public}@", sample.syncIdentifier)
                    return nil
                }

                return sample
            }

            guard !samples.isEmpty else {
                return []
            }

            let objects: [CachedGlucoseObject] = samples.map { sample in
                let object = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                object.create(from: sample,
                              provenanceIdentifier: self.provenanceIdentifier,
                              healthKitStorageDelay: self.healthKitStorageDelayIfAllowed)
                return object
            }

            if let error = self.cacheStore.save() {
                throw error
            }

            return objects.map { StoredGlucoseSample(managedObject: $0) }
        }

        await self.handleUpdatedGlucoseData()
        return storedSamples
    }

    func saveSamplesToHealthKit() async {
        guard let hkSampleStore else {
            return
        }

        do {
            let objects = try await cacheStore.managedObjectContext.perform {
                let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                request.predicate = NSPredicate(format: "healthKitEligibleDate <= %@", Date() as NSDate)
                request.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]   // Maintains modificationCounter order

                return try self.cacheStore.managedObjectContext.fetch(request)
            }

            guard !objects.isEmpty else {
                return
            }

            let quantitySamples = objects.map { $0.quantitySample }

            try await hkSampleStore.healthStore.save(quantitySamples)

            try await cacheStore.managedObjectContext.perform {
                for (object, quantitySample) in zip(objects, quantitySamples) {
                    object.uuid = quantitySample.uuid
                    object.healthKitEligibleDate = nil
                    object.updateModificationCounter()  // Maintains modificationCounter order
                }
                if let error = self.cacheStore.save() {
                    throw error
                }
            }
            self.log.default("Stored %d eligible glucose samples to HealthKit", objects.count)

        } catch {
            self.log.error("Error saving samples to HealthKit: %{public}@", String(describing: error))
        }
    }

    private func addGlucoseSample(for sample: HKQuantitySample) throws -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        // Are there any objects matching the UUID?
        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", sample.uuid as NSUUID)
        request.fetchLimit = 1

        let count = try cacheStore.managedObjectContext.count(for: request)
        guard count == 0 else {
            return false
        }

        // Add an object for this UUID
        let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
        object.create(from: sample)

        return true
    }

    private func deleteGlucoseSamples(withUUIDs uuids: [UUID], batchSize: Int = 500) throws -> Int {
        dispatchPrecondition(condition: .onQueue(queue))

        var count = 0
        for batch in uuids.chunked(into: batchSize) {
            let predicate = NSPredicate(format: "uuid IN %@", batch.map { $0 as NSUUID })
            count += try cacheStore.managedObjectContext.purgeObjects(of: CachedGlucoseObject.self, matching: predicate)
        }
        return count
    }

    ///
    /// - Parameters:
    ///   - since: Only consider glucose valid after or at this date
    /// - Returns: The latest CGM glucose, if available in the time period specified
    public func getLatestCGMGlucose(since: Date, completion: @escaping (_ result: Result<StoredGlucoseSample?, Error>) -> Void) {
        queue.async {
            self.cacheStore.managedObjectContext.performAndWait {
                let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                request.predicate = NSPredicate(format: "startDate >= %@ AND wasUserEntered == NO", since as NSDate)
                request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
                request.fetchLimit = 1

                do {
                    let objects = try self.cacheStore.managedObjectContext.fetch(request)
                    let samples = objects.map { StoredGlucoseSample(managedObject: $0) }
                    completion(.success(samples.first))
                } catch let error {
                    self.log.error("Error in getLatestCGMGlucose: %{public}@", String(describing: error))
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Watch Synchronization

extension GlucoseStore {

    /// Get glucose samples in main app to deliver to Watch extension
    public func getSyncGlucoseSamples(start: Date? = nil, end: Date? = nil, completion: @escaping (_ result: Result<[StoredGlucoseSample], Error>) -> Void) {
        queue.async {
            var samples: [StoredGlucoseSample] = []
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    samples = try self.getCachedGlucoseObjects(start: start, end: end).map { StoredGlucoseSample(managedObject: $0) }
                } catch let coreDataError {
                    error = coreDataError
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(samples))
        }
    }

    public func getSyncGlucoseSamples(start: Date? = nil, end: Date? = nil) async throws -> [StoredGlucoseSample] {
        try await withCheckedThrowingContinuation { continuation in
            getSyncGlucoseSamples(start: start, end: end) { result in
                continuation.resume(with: result)
            }
        }
    }


    /// Store glucose samples in Watch extension
    public func setSyncGlucoseSamples(_ objects: [StoredGlucoseSample]) async throws {
        guard !objects.isEmpty else {
            return
        }

        try await self.cacheStore.managedObjectContext.perform {

            objects.forEach {
                let object = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                object.update(from: $0)
            }

            if let error = self.cacheStore.save() {
                throw error
            }
        }

        await self.handleUpdatedGlucoseData()
    }
}

// MARK: - Cache Management

extension GlucoseStore {
    public var earliestCacheDate: Date {
        return Date(timeIntervalSinceNow: -cacheLength)
    }

    /// Purge all glucose samples from the glucose store and HealthKit (matching the specified device ).
    ///
    /// - Parameters:
    ///   - device: The device to use in matching HealthKit glucose objects.
    public func purgeAllGlucose(for device: HKDevice) async throws {
        try await purgeCachedGlucoseObjects()
        if let hkSampleStore = self.hkSampleStore {
            let predicate = HKQuery.predicateForObjects(from: [device])
            let _ = try await hkSampleStore.healthStore.deleteObjects(of: HealthKitSampleStore.glucoseType, predicate: predicate)
        }
        await self.handleUpdatedGlucoseData()
    }

    /// Purge all glucose samples from the glucose store and HealthKit (matching the specified source ).
    ///
    /// - Parameters:
    ///   - device: The source to use in matching HealthKit glucose objects.
    public func purgeAllGlucose(for source: HKSource) async throws {
        try await purgeCachedGlucoseObjects()
        if let hkSampleStore = self.hkSampleStore {
            let predicate = HKQuery.predicateForObjects(from: [source])
            let _ = try await hkSampleStore.healthStore.deleteObjects(of: HealthKitSampleStore.glucoseType, predicate: predicate)
        }
        await self.handleUpdatedGlucoseData()
    }

    private func purgeExpiredCachedGlucoseObjects() async {
        do {
            try await internal_purgeCachedGlucoseObjects(before: earliestCacheDate)
        } catch {
            self.log.error("Error purging expired glucose objects: %{public}@", String(describing: error))
        }
    }

    /// Purge cached glucose objects from the glucose store.
    ///
    /// - Parameters:
    ///   - date: Purge cached glucose objects with start date before this date.
    public func purgeCachedGlucoseObjects(before date: Date? = nil) async throws {
        try await self.internal_purgeCachedGlucoseObjects(before: date)
        await self.handleUpdatedGlucoseData()
    }

    private func internal_purgeCachedGlucoseObjects(before date: Date? = nil) async throws {
        try await cacheStore.managedObjectContext.perform {
            var predicate: NSPredicate?
            if let date = date {
                predicate = NSPredicate(format: "startDate < %@", date as NSDate)
            }
            let count = try self.cacheStore.managedObjectContext.purgeObjects(of: CachedGlucoseObject.self, matching: predicate)
            self.log.default("Purged %d CachedGlucoseObjects", count)
        }
    }

    private func purgeExpiredManagedDataFromHealthKit(before date: Date) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard let managedDataInterval = managedDataInterval, let hkSampleStore else {
            return
        }

        let end = min(Date(timeIntervalSinceNow: -managedDataInterval), date)
        let predicate = HKQuery.predicateForSamples(withStart: Date(timeIntervalSinceNow: -maxPurgeInterval), end: end)
        hkSampleStore.healthStore.deleteObjects(of: HealthKitSampleStore.glucoseType, predicate: predicate) { (success, count, error) -> Void in
            // error is expected and ignored if protected data is unavailable
            if success {
                self.log.debug("Successfully purged %d HealthKit objects older than %{public}@", count, String(describing: end))
            }
        }
    }

    private func handleUpdatedGlucoseData() async {
        await self.purgeExpiredCachedGlucoseObjects()
        await self.updateLatestGlucose()
        Task {
            await self.saveSamplesToHealthKit()
        }

        NotificationCenter.default.post(name: GlucoseStore.glucoseSamplesDidChange, object: self)
        delegate?.glucoseStoreHasUpdatedGlucoseData(self)
    }
}

// MARK: - Remote Data Service Query

extension GlucoseStore {
    public struct QueryAnchor: Equatable, RawRepresentable {
        public typealias RawValue = [String: Any]

        internal var modificationCounter: Int64

        public init() {
            self.modificationCounter = 0
        }

        public init?(rawValue: RawValue) {
            guard let modificationCounter = rawValue["modificationCounter"] as? Int64 else {
                return nil
            }
            self.modificationCounter = modificationCounter
        }

        public var rawValue: RawValue {
            var rawValue: RawValue = [:]
            rawValue["modificationCounter"] = modificationCounter
            return rawValue
        }
    }

    public enum GlucoseQueryResult {
        case success(QueryAnchor, [StoredGlucoseSample])
        case failure(Error)
    }

    public func executeGlucoseQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (GlucoseQueryResult) -> Void) {
        queue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryResult = [StoredGlucoseSample]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, []))
                return
            }

            self.cacheStore.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()

                storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                storedRequest.fetchLimit = limit

                do {
                    let stored = try self.cacheStore.managedObjectContext.fetch(storedRequest)
                    if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.modificationCounter = modificationCounter
                    }
                    queryResult.append(contentsOf: stored.compactMap { StoredGlucoseSample(managedObject: $0) })
                } catch let error {
                    queryError = error
                    return
                }
            }

            if let queryError = queryError {
                completion(.failure(queryError))
                return
            }

            completion(.success(queryAnchor, queryResult))
        }
    }
}

// MARK: - Critical Event Log Export

extension GlucoseStore: CriticalEventLog {
    private var exportProgressUnitCountPerObject: Int64 { 1 }
    private var exportFetchLimit: Int { Int(criticalEventLogExportProgressUnitCountPerFetch / exportProgressUnitCountPerObject) }

    public var exportName: String { "Glucose.json" }

    public func exportProgressTotalUnitCount(startDate: Date, endDate: Date? = nil) -> Result<Int64, Error> {
        var result: Result<Int64, Error>?

        self.cacheStore.managedObjectContext.performAndWait {
            do {
                let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                request.predicate = self.exportDatePredicate(startDate: startDate, endDate: endDate)

                let objectCount = try self.cacheStore.managedObjectContext.count(for: request)
                result = .success(Int64(objectCount) * exportProgressUnitCountPerObject)
            } catch let error {
                result = .failure(error)
            }
        }

        return result!
    }

    public func export(startDate: Date, endDate: Date, to stream: DataOutputStream, progress: Progress) -> Error? {
        let encoder = JSONStreamEncoder(stream: stream)
        var modificationCounter: Int64 = 0
        var fetching = true
        var error: Error?

        while fetching && error == nil {
            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    guard !progress.isCancelled else {
                        throw CriticalEventLogError.cancelled
                    }

                    let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "modificationCounter > %d", modificationCounter),
                                                                                            self.exportDatePredicate(startDate: startDate, endDate: endDate)])
                    request.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                    request.fetchLimit = self.exportFetchLimit

                    let objects = try self.cacheStore.managedObjectContext.fetch(request)
                    if objects.isEmpty {
                        fetching = false
                        return
                    }

                    try encoder.encode(objects)

                    modificationCounter = objects.last!.modificationCounter

                    progress.completedUnitCount += Int64(objects.count) * exportProgressUnitCountPerObject
                } catch let fetchError {
                    error = fetchError
                }
            }
        }

        if let closeError = encoder.close(), error == nil {
            error = closeError
        }

        return error
    }

    private func exportDatePredicate(startDate: Date, endDate: Date? = nil) -> NSPredicate {
        var predicate = NSPredicate(format: "startDate >= %@", startDate as NSDate)
        if let endDate = endDate {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, NSPredicate(format: "startDate < %@", endDate as NSDate)])
        }
        return predicate
    }
}

// MARK: - Core Data (Bulk) - TEST ONLY

extension GlucoseStore {
    public func addNewGlucoseSamples(samples: [NewGlucoseSample], completion: @escaping (Error?) -> Void) {
        guard !samples.isEmpty else {
            completion(nil)
            return
        }

        queue.async {
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                for sample in samples {
                    let object = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                    object.create(from: sample, provenanceIdentifier: self.provenanceIdentifier, healthKitStorageDelay: self.healthKitStorageDelayIfAllowed)
                }
                error = self.cacheStore.save()
            }

            guard error == nil else {
                completion(error)
                return
            }

            self.log.info("Added %d CachedGlucoseObjects", samples.count)
            self.delegate?.glucoseStoreHasUpdatedGlucoseData(self)
            completion(nil)
        }
    }

    public func addNewGlucoseSamples(samples: [NewGlucoseSample]) async throws {
        try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
            self.addNewGlucoseSamples(samples: samples) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        })
    }
}


// MARK: - Issue Report

extension GlucoseStore {
    /// Generates a diagnostic report about the current state.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completionHandler: A closure called once the report has been generated. The closure takes a single argument of the report string.
    public func generateDiagnosticReport() async -> String {
        await withCheckedContinuation { continuation in
            queue.async {
                var report: [String] = [
                    "## GlucoseStore",
                    "",
                    "* latestGlucoseValue: \(String(reflecting: self.latestGlucose))",
                    "* managedDataInterval: \(self.managedDataInterval ?? 0)",
                    "* cacheLength: \(self.cacheLength)",
                    "* momentumDataInterval: \(self.momentumDataInterval)",
                    "* HealthKitSampleStore: \(self.hkSampleStore?.debugDescription ?? "nil")",
                    "",
                    "### cachedGlucoseSamples",
                ]

                switch self.getGlucoseSamples(start: Date(timeIntervalSinceNow: -.hours(24))) {
                case .failure(let error):
                    report.append("Error: \(error)")
                case .success(let samples):
                    for sample in samples {
                        report.append(String(describing: sample))
                    }
                }

                report.append("")

                continuation.resume(returning: report.joined(separator: "\n"))
            }
        }
    }
}
