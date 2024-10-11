//
//  InsulinDeliveryStore.swift
//  InsulinKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit
import CoreData
import os.log

public protocol InsulinDeliveryStoreDelegate: AnyObject {

    /**
     Informs the delegate that the insulin delivery store has updated dose data.

     - Parameter insulinDeliveryStore: The insulin delivery store that has updated dose data.
     */
    func insulinDeliveryStoreHasUpdatedDoseData(_ insulinDeliveryStore: InsulinDeliveryStore)

}

/// Manages insulin dose data in Core Data and optionally reads insulin dose data from HealthKit.
///
/// Scheduled doses (e.g. a bolus or temporary basal) shouldn't be written to this store until they've
/// been delivered into the patient, which means its common for this store data to slightly lag
/// behind the dose data used for algorithmic calculation.
///
/// This store data isn't a substitute for an insulin pump's diagnostic event history, but doses fetched
/// from this store can reduce the amount of repeated communication with an insulin pump.
public class InsulinDeliveryStore {
    
    /// Notification posted when dose entries were changed, either via direct add or from HealthKit
    public static let doseEntriesDidChange = NSNotification.Name(rawValue: "com.loopkit.InsulinDeliveryStore.doseEntriesDidChange")

    private let queue = DispatchQueue(label: "com.loopkit.InsulinDeliveryStore.queue", qos: .utility)

    private let log = OSLog(category: "InsulinDeliveryStore")

    /// The most-recent end date for an immutable basal dose entry written by LoopKit
    /// Should only be accessed on queue
    private var lastImmutableBasalEndDate: Date? {
        didSet {
            test_lastImmutableBasalEndDateDidSet?()
        }
    }

    internal var test_lastImmutableBasalEndDateDidSet: (() -> Void)?

    public weak var delegate: InsulinDeliveryStoreDelegate?

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

    /// The interval of insulin delivery data to keep in cache
    public let cacheLength: TimeInterval

    private let storeSamplesToHealthKit: Bool

    private let cacheStore: PersistenceController

    private let provenanceIdentifier: String

    static let healthKitQueryAnchorMetadataKey = "com.loopkit.InsulinDeliveryStore.hkQueryAnchor"

    public init(
        healthKitSampleStore: HealthKitSampleStore? = nil,
        storeSamplesToHealthKit: Bool = true,
        cacheStore: PersistenceController,
        observationEnabled: Bool = true,
        cacheLength: TimeInterval = 24 /* hours */ * 60 /* minutes */ * 60 /* seconds */,
        provenanceIdentifier: String,
        test_currentDate: Date? = nil
    ) async {
        self.storeSamplesToHealthKit = storeSamplesToHealthKit
        self.cacheStore = cacheStore
        self.cacheLength = cacheLength
        self.provenanceIdentifier = provenanceIdentifier
        self.hkSampleStore = healthKitSampleStore
        self.test_currentDate = test_currentDate

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

            await self.updateLastImmutableBasalEndDate()

            let anchor = await cacheStore.fetchAnchor(key: InsulinDeliveryStore.healthKitQueryAnchorMetadataKey)
            self.queue.sync {
                self.hkSampleStore?.setInitialQueryAnchor(anchor)
            }
        } catch {
            log.error("CacheStore initialization failed: %{public}@", String(describing: error))
        }
    }
}

// MARK: - HKSampleStoreCompositionalDelegate
extension InsulinDeliveryStore: HealthKitSampleStoreDelegate {
    // MARK: - HealthKitSampleStore

    public func storeQueryAnchor(_ anchor: HKQueryAnchor) {
        cacheStore.storeAnchor(anchor, key: InsulinDeliveryStore.healthKitQueryAnchorMetadataKey)
        self.log.default("stored query anchor %{public}@", String(describing: anchor))
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
                            if try self.addDoseEntry(for: sample) {
                                self.log.debug("Saved sample %@ into cache from HKAnchoredObjectQuery", sample.uuid.uuidString)
                                changed = true
                            } else {
                                self.log.default("Sample %@ from HKAnchoredObjectQuery already present in cache", sample.uuid.uuidString)
                            }
                        }
                    }

                    // Delete deleted samples
                    let count = try self.deleteDoseEntries(withUUIDs: deleted.map { $0.uuid })
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

            guard changed else {
                completion(true)
                return
            }

            Task {
                await self.handleUpdatedDoseData()
            }

            completion(true)
        }
    }
}

// MARK: - Fetching

extension InsulinDeliveryStore {
    /// Retrieves dose entries within the specified date range.
    ///
    /// - Parameters:
    ///   - start: The earliest date of dose entries to retrieve, if provided.
    ///   - end: The latest date of dose entries to retrieve, if provided.
    ///   - includeMutable: Whether to include mutable dose entries or not. Defaults to false.
    ///   - includeDeleted: Whether to include deleted dose entries or not. Defaults to false.
    ///   - returns: An array of dose entries, in chronological order by startDate, or error.
    public func getDoseEntries(start: Date? = nil, end: Date? = nil, includeMutable: Bool = false, includeDeleted: Bool = false) async throws -> [DoseEntry] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: self.getDoseEntriesInternal(start: start, end: end, includeMutable: includeMutable, includeDeleted: includeDeleted))
            }
        }
    }

    private func getDoseEntriesInternal(start: Date? = nil, end: Date? = nil, includeMutable: Bool = false, includeDeleted: Bool = false) -> Result<[DoseEntry], Error> {
        dispatchPrecondition(condition: .onQueue(queue))

        var entries: [DoseEntry] = []
        var error: Error?

        cacheStore.managedObjectContext.performAndWait {
            do {
                entries = try self.getCachedInsulinDeliveryObjects(start: start, end: end, includeMutable: includeMutable, includeDeleted: includeDeleted).map { $0.dose }
            } catch let coreDataError {
                error = coreDataError
            }
        }

        if let error = error {
            self.log.error("Error getting CachedInsulinDeliveryObjects: %{public}@", String(describing: error))
            return .failure(error)
        }

        return .success(entries)
    }

    private func getCachedInsulinDeliveryObjects(start: Date? = nil, end: Date? = nil, includeMutable: Bool = false, includeDeleted: Bool = false) throws -> [CachedInsulinDeliveryObject] {
        dispatchPrecondition(condition: .onQueue(queue))

        // Match all doses whose start OR end dates fall in the start and end date range, if specified. Therefore, we ensure the
        // dose end date is AFTER the start date, if specified, and the dose start date is BEFORE the end date, if specified.
        var predicates: [NSPredicate] = []
        if let start = start {
            predicates.append(NSPredicate(format: "endDate >= %@", start as NSDate))
        }
        if let end = end {
            predicates.append(NSPredicate(format: "startDate <= %@", end as NSDate))    // Note: Using <= rather than < to match previous behavior
        }
        if !includeMutable {
            predicates.append(NSPredicate(format: "isMutable == NO"))
        }
        if !includeDeleted {
            predicates.append(NSPredicate(format: "deletedAt == NIL"))
        }

        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
        request.predicate = (predicates.count > 1) ? NSCompoundPredicate(andPredicateWithSubpredicates: predicates) : predicates.first
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        return try self.cacheStore.managedObjectContext.fetch(request)
    }

    /// Fetches manually entered doses.
    ///
    /// - Parameters:
    ///   - startDate: The earliest dose startDate to include.
    ///   - chronological: Whether to return the objects in chronological or reverse-chronological order.
    ///   - limit: The maximum number of manually entered dose entries to return.
    /// - Returns: An array of manually entered dose dose entries in the specified order by date.
    public func getManuallyEnteredDoses(since startDate: Date, chronological: Bool = true, limit: Int? = nil, completion: @escaping (_ result: DoseStoreResult<[DoseEntry]>) -> Void) {
        queue.async {
            var doses: [DoseEntry] = []
            var error: DoseStore.DoseStoreError?

            self.cacheStore.managedObjectContext.performAndWait {
                let predicates = [NSPredicate(format: "deletedAt == NIL"),
                                  NSPredicate(format: "startDate >= %@", startDate as NSDate),
                                  NSPredicate(format: "manuallyEntered == YES")]

                let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: chronological)]
                if let limit = limit {
                    request.fetchLimit = limit
                }

                do {
                    doses = try self.cacheStore.managedObjectContext.fetch(request).compactMap{ $0.dose }
                } catch let fetchError as NSError {
                    error = .fetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
                } catch {
                    assertionFailure()
                }
            }

            if let error = error {
                completion(.failure(error))
            }

            completion(.success(doses))
        }
    }

    public func getManuallyEnteredDoses(since startDate: Date, chronological: Bool = true, limit: Int? = nil) async throws -> [DoseEntry] {
        try await withCheckedThrowingContinuation { continuation in
            getManuallyEnteredDoses(since: startDate, chronological: chronological, limit: limit) { result in
                switch result {
                case .success(let entries):
                    continuation.resume(returning: entries)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Retrieves boluses
    ///
    /// - Parameters:
    ///   - start:If non-nil, select boluses that ended after start.
    ///   - end: If non-nil, select boluses that started before end.
    ///   - limit: If non-nill, specify the max number of boluses to return.
    ///   - returns: A list of DoseEntry objects representing the most recent boluses
    public func getBoluses(start: Date? = nil, end: Date? = nil, limit: Int? = nil) async throws -> [DoseEntry] {
        return try await withCheckedThrowingContinuation({ continuation in
            queue.async {
                self.cacheStore.managedObjectContext.performAndWait {
                    let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()

                    var predicates = [NSPredicate(format: "deletedAt == NIL"), NSPredicate(format: "reason == %d", HKInsulinDeliveryReason.bolus.rawValue)]
                    if let start {
                        predicates.append(NSPredicate(format: "endDate >= %@", start as NSDate))
                    }
                    if let end {
                        predicates.append(NSPredicate(format: "startDate <= %@", end as NSDate))
                    }
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

                    request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
                    if let limit {
                        request.fetchLimit = limit
                    }

                    do {
                        let doses = try self.cacheStore.managedObjectContext.fetch(request).compactMap{ $0.dose }
                        continuation.resume(returning: doses)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        })
    }

    /// Returns the end date of the most recent basal dose entry.
    ///
    /// - Parameters:
    ///   - completion: A closure called when the date has been retrieved with date.
    ///   - result: The date, or error.
    func getLastImmutableBasalEndDate(_ completion: @escaping (Date?) -> Void) {
        queue.async {
            completion(self.lastImmutableBasalEndDate)
        }
    }

    func getLastImmutableBasalEndDate() async -> Date? {
        return await withCheckedContinuation { continuation in
            getLastImmutableBasalEndDate { date in
                continuation.resume(returning: date)
            }
        }
    }

    private func updateLastImmutableBasalEndDate() async {
        do {
            let endDate = try await cacheStore.managedObjectContext.perform {
                let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                        NSPredicate(format: "reason == %d", HKInsulinDeliveryReason.basal.rawValue),
                                                                                        NSPredicate(format: "hasLoopKitOrigin == YES"),
                                                                                        NSPredicate(format: "isMutable == NO")])
                request.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]
                request.fetchLimit = 1

                let objects = try self.cacheStore.managedObjectContext.fetch(request)
                return objects.first?.endDate
            }
            self.queue.sync {
                self.lastImmutableBasalEndDate = endDate
            }
        } catch {
            self.log.error("updateLastImmutableBasalEndDate failed: %@", String(describing: error))
        }
    }
}

// MARK: - Modification

extension InsulinDeliveryStore {
    /// Add dose entries to store.
    ///
    /// - Parameters:
    ///   - entries: The new dose entries to add to the store.
    ///   - device: The optional device used for the new dose entries.
    ///   - syncVersion: The sync version used for the new dose entries.
    ///   - resolveMutable: Whether to update or delete any pre-existing mutable dose entries based upon any matching incoming mutable dose entries. Any previously stored mutable doses that are not also included in entries will be marked as deleted.
    ///   - result: Success or error.
    func addDoseEntries(_ entries: [DoseEntry], from device: HKDevice?, syncVersion: Int, resolveMutable: Bool = false) async throws {
        guard !entries.isEmpty else {
            return
        }

        let (changed, resolvedSampleObjects) = try await self.cacheStore.managedObjectContext.perform {
            let now = self.currentDate()
            var mutableObjects: [CachedInsulinDeliveryObject] = []

            // If we are resolving mutable objects, then fetch all non-deleted mutable objects and initially mark as deleted
            // If an incoming entry matches via syncIdentifier, then update and mark as NOT deleted
            if resolveMutable {
                let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                        NSPredicate(format: "isMutable == YES")])
                mutableObjects = try self.cacheStore.managedObjectContext.fetch(request)
                mutableObjects.forEach { $0.deletedAt = now }
            }

            let resolvedSampleObjects: [(HKQuantitySample, CachedInsulinDeliveryObject)] = entries.compactMap { (entry) -> (HKQuantitySample, CachedInsulinDeliveryObject)? in
                guard entry.syncIdentifier != nil else {
                    self.log.error("Ignored adding dose entry without sync identifier: %{public}@", String(reflecting: entry))
                    return nil
                }

                guard let quantitySample = HKQuantitySample(type: HealthKitSampleStore.insulinQuantityType,
                                                            unit: HKUnit.internationalUnit(),
                                                            dose: entry,
                                                            device: device,
                                                            provenanceIdentifier: self.provenanceIdentifier,
                                                            syncVersion: syncVersion)
                else {
                    self.log.error("Failure to create HKQuantitySample from DoseEntry: %{public}@", String(describing: entry))
                    return nil
                }

                // If we have a mutable object that matches this sync identifier, then update, it will mark as NOT deleted
                if let object = mutableObjects.first(where: { $0.provenanceIdentifier == self.provenanceIdentifier && $0.syncIdentifier == entry.syncIdentifier }) {
                    self.log.debug("ISD Update: %{public}@", String(describing: entry))
                    object.update(from: entry)
                    return (quantitySample, object)

                // Otherwise, add new object
                } else {
                    let object = CachedInsulinDeliveryObject(context: self.cacheStore.managedObjectContext)
                    object.create(from: entry, by: self.provenanceIdentifier, at: now)
                    self.log.debug("IDS Add: %{public}@", String(describing: entry))
                    return (quantitySample, object)
                }
            }

            for dose in mutableObjects {
                if dose.deletedAt != nil {
                    self.log.debug("Delete: %{public}@", String(describing: dose))
                }
            }

            let changed = !mutableObjects.isEmpty || !resolvedSampleObjects.isEmpty
            guard changed else {
                return (false, resolvedSampleObjects)
            }

            let error = self.cacheStore.save()
            if let error {
                throw error
            }

            return (changed, resolvedSampleObjects)
        }

        // Only save immutable objects to HealthKit
        await self.saveEntriesToHealthKit(resolvedSampleObjects.filter { !$0.1.isMutable && !$0.1.isFault })

        guard changed else {
            return
        }

        await self.handleUpdatedDoseData()

    }

    /// Add doses to store, updating any existing doses that have the same syncIdentifier.
    ///
    /// - Parameters:
    ///   - entries: The new dose entries to add to the store.
    func syncDoseEntries(_ entries: [DoseEntry], updateExistingRecords: Bool = true) async throws {

        try await withCheckedThrowingContinuation({ continuation in
            guard !entries.isEmpty else {
                continuation.resume()
                return
            }

            queue.async {
                var error: Error?

                self.cacheStore.managedObjectContext.performAndWait {
                    do {
                        let now = self.currentDate()

                        let objectsToUpdate: [CachedInsulinDeliveryObject]

                        if updateExistingRecords {
                            let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "syncIdentifier IN %@", entries.map { $0.syncIdentifier })])
                            objectsToUpdate = try self.cacheStore.managedObjectContext.fetch(request)
                        } else {
                            objectsToUpdate = []
                        }

                        for entry in entries {
                            guard entry.syncIdentifier != nil else {
                                self.log.error("Ignored adding dose entry without sync identifier: %{public}@", String(reflecting: entry))
                                continue
                            }

                            // If we have a mutable object that matches this sync identifier, then update, it will mark as NOT deleted
                            if let object = objectsToUpdate.first(where: { $0.syncIdentifier == entry.syncIdentifier }) {
                                self.log.debug("Update: %{public}@", String(describing: entry))
                                object.update(from: entry)
                            } else {
                                let object = CachedInsulinDeliveryObject(context: self.cacheStore.managedObjectContext)
                                object.create(from: entry, by: self.provenanceIdentifier, at: now)
                                self.log.debug("Add: %{public}@", String(describing: entry))
                            }
                        }
                        error = self.cacheStore.save()
                    } catch let coreDataError {
                        error = coreDataError
                    }
                }

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                Task {
                    await self.handleUpdatedDoseData()
                }

                continuation.resume()
            }
        })
    }


    private func saveEntriesToHealthKit(_ sampleObjects: [(HKQuantitySample, CachedInsulinDeliveryObject)]) async {

        guard storeSamplesToHealthKit, !sampleObjects.isEmpty, let hkSampleStore else {
            return
        }

        // Save objects to HealthKit, log any errors, but do not fail
        do {
            try await hkSampleStore.healthStore.save(sampleObjects.map { (sample, _) in sample })
            // Update Core Data with the changes, log any errors, but do not fail
            await cacheStore.managedObjectContext.perform {
                sampleObjects.forEach { (sample, object) in object.uuid = sample.uuid }
                if let error = self.cacheStore.save() {
                    self.log.error("Error updating CachedInsulinDeliveryObjects after saving HealthKit objects: %{public}@", String(describing: error))
                    sampleObjects.forEach { (_, object) in object.uuid = nil }
                }
            }
        } catch {
            self.log.error("Error saving HealthKit objects: %{public}@", String(describing: error))
        }
    }

    private func addDoseEntry(for sample: HKQuantitySample) throws -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        // Is entire sample before earliest cache date?
        guard sample.endDate >= earliestCacheDate else {
            return false
        }

        // Are there any objects matching the UUID?
        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", sample.uuid as NSUUID)
        request.fetchLimit = 1

        let count = try cacheStore.managedObjectContext.count(for: request)
        guard count == 0 else {
            return false
        }

        // Add an object for this UUID
        let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
        object.create(fromExisting: sample, on: self.currentDate())

        return true
    }
    
    func deleteDose(bySyncIdentifier syncIdentifier: String, _ completion: @escaping (String?) -> Void) {
        queue.async {
            var errorString: String? = nil
            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                            NSPredicate(format: "syncIdentifier == %@", syncIdentifier)])
                    request.fetchBatchSize = 100
                    let objects = try self.cacheStore.managedObjectContext.fetch(request)
                    if !objects.isEmpty {
                        let deletedAt = self.currentDate()
                        for object in objects {
                            object.deletedAt = deletedAt
                        }
                        self.cacheStore.save()
                    }
                    
                    let healthKitPredicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [syncIdentifier])
                    if let hkSampleStore = self.hkSampleStore {
                        hkSampleStore.healthStore.deleteObjects(of: HealthKitSampleStore.insulinQuantityType, predicate: healthKitPredicate)
                        { success, deletedObjectCount, error in
                            if let error = error {
                                self.log.error("Unable to delete dose from Health: %@", error.localizedDescription)
                            }
                        }
                    }
                } catch let error {
                    errorString = "Error deleting CachedInsulinDeliveryObject: " + error.localizedDescription
                    return
                }
            }
            Task {
                await self.handleUpdatedDoseData()
            }
            completion(errorString)
        }
    }

    func deleteDose(with uuidToDelete: UUID, _ completion: @escaping (String?) -> Void) {
        queue.async {
            var errorString: String? = nil
            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let count = try self.deleteDoseEntries(withUUIDs: [uuidToDelete])
                    guard count > 0 else {
                        errorString = "Cannot find CachedInsulinDeliveryObject to delete"
                        return
                    }
                    self.cacheStore.save()
                } catch let error {
                    errorString = "Error deleting CachedInsulinDeliveryObject: " + error.localizedDescription
                    return
                }
            }
            Task {
                await self.handleUpdatedDoseData()
            }
            completion(errorString)
        }
    }

    private func deleteDoseEntries(withUUIDs uuids: [UUID], batchSize: Int = 500) throws -> Int {
        dispatchPrecondition(condition: .onQueue(queue))

        let deletedAt = self.currentDate()

        var count = 0
        for batch in uuids.chunked(into: batchSize) {
            let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                    NSPredicate(format: "uuid IN %@", batch.map { $0 as NSUUID })])
            let objects = try self.cacheStore.managedObjectContext.fetch(request)
            for object in objects {
                object.deletedAt = deletedAt
            }
            count += objects.count
        }
        return count
    }

    public func deleteAllManuallyEnteredDoses(since startDate: Date, _ completion: @escaping (_ error: DoseStore.DoseStoreError?) -> Void) {
        queue.async {
            var doseStoreError: DoseStore.DoseStoreError?
            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                            NSPredicate(format: "startDate >= %@", startDate as NSDate),
                                                                                            NSPredicate(format: "manuallyEntered == YES")])
                    request.fetchBatchSize = 100
                    let objects = try self.cacheStore.managedObjectContext.fetch(request)
                    if !objects.isEmpty {
                        let deletedAt = self.currentDate()
                        for object in objects {
                            object.deletedAt = deletedAt
                        }
                        doseStoreError = DoseStore.DoseStoreError(error: self.cacheStore.save())
                    }
                }
                catch let error as NSError {
                    doseStoreError = DoseStore.DoseStoreError(error: .coreDataError(error))
                }
            }
            Task {
                await self.handleUpdatedDoseData()
            }
            completion(doseStoreError)
        }
    }

    public func deleteAllManuallyEnteredDoses(since startDate: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            deleteAllManuallyEnteredDoses(since: startDate) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Cache Management

extension InsulinDeliveryStore {
    var earliestCacheDate: Date {
        return currentDate(timeIntervalSinceNow: -cacheLength)
    }

    /// Purge all dose entries from the insulin delivery store and HealthKit (matching the specified device).
    ///
    /// - Parameters:
    ///   - device: The HealthKit device to match HealthKit insulin samples.
    public func purgeDoseEntriesForDevice(_ device: HKDevice) async throws {
        if let hkSampleStore {
            await self.purgeCachedInsulinDeliveryObjects()
            let predicate = HKQuery.predicateForObjects(from: [device])
            let _ = try await hkSampleStore.healthStore.deleteObjects(of: HealthKitSampleStore.insulinQuantityType, predicate: predicate)
            await self.handleUpdatedDoseData()
        }
    }

    /// Purge all dose entries from the insulin delivery store and HealthKit (matching the specified source).
    ///
    /// - Parameters:
    ///   - source: The HealthKit source to match HealthKit insulin samples.
    public func purgeDoseEntriesForSource(_ source: HKSource) async throws {
        if let hkSampleStore {
            await self.purgeCachedInsulinDeliveryObjects()
            let predicate = HKQuery.predicateForObjects(from: [source])
            let _ = try await hkSampleStore.healthStore.deleteObjects(of: HealthKitSampleStore.insulinQuantityType, predicate: predicate)
            await self.handleUpdatedDoseData()
        }
    }


    func purgeExpiredCachedInsulinDeliveryObjects() async {
        await internal_purgeCachedInsulinDeliveryObjects(before: earliestCacheDate)
    }

    /// Purge cached insulin delivery objects from the insulin delivery store.
    ///
    /// - Parameters:
    ///   - date: Purge cached insulin delivery objects with start date before this date.
    public func purgeCachedInsulinDeliveryObjects(before date: Date? = nil) async {
        await internal_purgeCachedInsulinDeliveryObjects(before: date)
        await handleUpdatedDoseData()
    }

    private func internal_purgeCachedInsulinDeliveryObjects(before date: Date? = nil) async {
        await cacheStore.managedObjectContext.perform {
            do {
                let predicate = date.map { NSPredicate(format: "endDate < %@", $0 as NSDate) }
                let count = try self.cacheStore.managedObjectContext.purgeObjects(of: CachedInsulinDeliveryObject.self, matching: predicate)
                if count > 0 {
                    self.log.default("Purged %d CachedInsulinDeliveryObjects", count)
                }
            } catch {
                self.log.error("Unable to purge CachedInsulinDeliveryObjects: %{public}@", String(describing: error))
            }
        }
    }

    private func handleUpdatedDoseData() async {
        await self.purgeExpiredCachedInsulinDeliveryObjects()
        await self.updateLastImmutableBasalEndDate()

        // TODO: simplify to one signal mechanism
        NotificationCenter.default.post(name: InsulinDeliveryStore.doseEntriesDidChange, object: self)
        self.delegate?.insulinDeliveryStoreHasUpdatedDoseData(self)
    }
}

// MARK: - Issue Report

extension InsulinDeliveryStore {
    /// Generates a diagnostic report about the current state
    public func generateDiagnosticReport() async -> String {
        var report: [String] = [
            "### InsulinDeliveryStore",
            "* cacheLength: \(self.cacheLength)",
            "* HealthKitSampleStore: \(self.hkSampleStore?.debugDescription ?? "nil")",
            "* lastImmutableBasalEndDate: \(String(describing: self.lastImmutableBasalEndDate))",
            "",
            "#### cachedDoseEntries",
        ]

        do {
            let entries = try await getDoseEntries(start: Date(timeIntervalSinceNow: -.hours(24)), includeMutable: true, includeDeleted: true)
            for entry in entries {
                report.append(String(describing: entry))
            }
        } catch {
            report.append("Error: \(error)")
        }
        report.append("")
        return report.joined(separator: "\n")
    }
}

// MARK: - Query

extension InsulinDeliveryStore {

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

    public enum DoseQueryResult {
        case success(QueryAnchor, [DoseEntry], [DoseEntry])
        case failure(Error)
    }

    public func executeDoseQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (DoseQueryResult) -> Void) {
        queue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryCreatedResult = [DoseEntry]()
            var queryDeletedResult = [DoseEntry]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, [], []))
                return
            }

            self.cacheStore.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()

                storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                storedRequest.fetchLimit = limit

                do {
                    let stored = try self.cacheStore.managedObjectContext.fetch(storedRequest)
                    if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.modificationCounter = modificationCounter
                    }
                    queryCreatedResult.append(contentsOf: stored.filter({ $0.deletedAt == nil }).compactMap { $0.dose })
                    queryDeletedResult.append(contentsOf: stored.filter({ $0.deletedAt != nil }).compactMap { $0.dose })
                } catch let error {
                    queryError = error
                }
            }

            if let queryError = queryError {
                completion(.failure(queryError))
                return
            }

            completion(.success(queryAnchor, queryCreatedResult, queryDeletedResult))
        }
    }
}

// MARK: - Unit Testing

extension InsulinDeliveryStore {
    public var test_lastImmutableBasalEndDate: Date? {
        get {
            var date: Date?
            queue.sync {
                date = self.lastImmutableBasalEndDate
            }
            return date
        }
        set {
            queue.sync {
                self.lastImmutableBasalEndDate = newValue
            }
        }
    }
}
