//
//  DoseStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/27/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import CoreData
import HealthKit
import os.log

public protocol DoseStoreDelegate: AnyObject {

    /**
     Informs the delegate that the dose store has updated pump data.

     - Parameter doseStore: The dose store that has updated pump data.
     */
    func doseStoreHasUpdatedPumpData(_ doseStore: DoseStore)

}

public enum DoseStoreResult<T> {
    case success(T)
    case failure(DoseStore.DoseStoreError)
}

/**
 Manages storage, retrieval, and calculation of insulin pump delivery data.
 
 Pump data are stored in the following tiers:
 
 * In-memory cache, used for IOB and insulin effect calculation
 ```
 0            [1.5 * insulinActionDuration]
 |––––––––––––––––––––—————————––|
 ```
 * On-disk Core Data store, unprotected
 ```
 0                           [24 hours]
 |––––––––––––––––––––––—————————|
 ```
 * HealthKit data, managed by the current application and persisted indefinitely
 ```
 0
 |––––––––––––––––––––––——————————————>
 ```

 Private members should be assumed to not be thread-safe, and access should be contained to within blocks submitted to `persistenceStore.managedObjectContext`, which executes them on a private, serial queue.
 */
public final class DoseStore {
    
    /// Notification posted when data was modifed.
    public static let valuesDidChange = NSNotification.Name(rawValue: "com.loopkit.DoseStore.valuesDidChange")

    public enum DoseStoreError: Error {
        case configurationError
        case initializationError(description: String, recoverySuggestion: String?)
        case persistenceError(description: String, recoverySuggestion: String?)
        case fetchError(description: String, recoverySuggestion: String?)

        init?(error: PersistenceController.PersistenceControllerError?) {
            if let error = error {
                self = .persistenceError(description: String(describing: error), recoverySuggestion: error.recoverySuggestion)
            } else {
                return nil
            }
        }
    }

    public weak var delegate: DoseStoreDelegate?

    private let log = OSLog(category: "DoseStore")
    
    public var longestEffectDuration: TimeInterval

    public var insulinModelProvider: InsulinModelProvider {
        get {
            return lockedInsulinModelProvider.value
        }
        set {
            lockedInsulinModelProvider.value = newValue

            persistenceController.managedObjectContext.perform {
                self.pumpEventQueryAfterDate = max(self.pumpEventQueryAfterDate, self.cacheStartDate)

                self.validateReservoirContinuity()
            }
        }
    }
    private let lockedInsulinModelProvider: Locked<InsulinModelProvider>
    
    /// A history of recently applied schedule overrides.
    private let overrideHistory: TemporaryScheduleOverrideHistory?

    public var basalProfile: BasalRateSchedule? {
        get {
            return lockedBasalProfile.value
        }
        set {
            lockedBasalProfile.value = newValue

            persistenceController.managedObjectContext.perform {
                self.clearReservoirNormalizedDoseCache()
            }
        }
    }
    private let lockedBasalProfile: Locked<BasalRateSchedule?>

    /// The basal profile, applying recent overrides relative to the current moment in time.
    public var basalProfileApplyingOverrideHistory: BasalRateSchedule? {
        if let basalProfile = basalProfile {
            return overrideHistory?.resolvingRecentBasalSchedule(basalProfile) ?? basalProfile
        } else {
            return nil
        }
    }

    public var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        get {
            return lockedInsulinSensitivitySchedule.value
        }
        set {
            lockedInsulinSensitivitySchedule.value = newValue
        }
    }
    private let lockedInsulinSensitivitySchedule: Locked<InsulinSensitivitySchedule?>

    /// The insulin sensitivity schedule, applying recent overrides relative to the current moment in time.
    public var insulinSensitivityScheduleApplyingOverrideHistory: InsulinSensitivitySchedule? {
        if let insulinSensitivitySchedule = insulinSensitivitySchedule {
            return overrideHistory?.resolvingRecentInsulinSensitivitySchedule(insulinSensitivitySchedule)
        } else {
            return nil
        }
    }

    /// The computed EGP schedule based on the basal profile and insulin sensitivity schedule.
    public var egpSchedule: EGPSchedule? {
        guard let basalProfile = basalProfile, let insulinSensitivitySchedule = insulinSensitivitySchedule else {
            return nil
        }
        return .egpSchedule(basalSchedule: basalProfile, insulinSensitivitySchedule: insulinSensitivitySchedule)
    }

    public let insulinDeliveryStore: InsulinDeliveryStore

    /// The HealthKit sample type managed by this store
    public var sampleType: HKSampleType {
        return insulinDeliveryStore.sampleType
    }

    /// True if the store requires authorization
    public var authorizationRequired: Bool {
        return insulinDeliveryStore.authorizationRequired
    }

    /// True if the user has explicitly denied access to any required share types
    public var sharingDenied: Bool {
        return insulinDeliveryStore.sharingDenied
    }

    /// The representation of the insulin pump for Health storage
    public var device: HKDevice? {
        get {
            return lockedDevice.value
        }
        set {
            lockedDevice.value = newValue
        }
    }
    private let lockedDevice = Locked<HKDevice?>(nil)

    /// Whether the pump generates events indicating the start of a scheduled basal rate after it had been interrupted.
    public var pumpRecordsBasalProfileStartEvents: Bool = false

    /// The sync version used for new samples written to HealthKit
    /// Choose a lower or higher sync version if the same sample might be written twice (e.g. from an extension and from an app) for deterministic conflict resolution
    public let syncVersion: Int

    /// Window for retrieving historical doses that might be used to reconcile current events
    private let pumpEventReconciliationWindow = TimeInterval(hours: 24)

    // MARK: -

    /// Initializes and configures a new store
    ///
    /// - Parameters:
    ///   - healthStore: The HealthKit store for reading & writing insulin delivery
    ///   - observeHealthKitSamplesFromOtherApps: Whether or not this Store should read HealthKit data written by other apps
    ///   - storeSamplesToHealthKit: Whether or not this Store should store samples in HealthKit
    ///   - cacheStore: The cache store for reading & writing short-term intermediate data
    ///   - observationEnabled: Whether the store should observe changes from HealthKit
    ///   - cacheLength: Maximum age of data to keep in the store.
    ///   - insulinModelProvider: A factory for producing insulin models based on insulin type
    ///   - longestEffectDuration: This determines the oldest age of doses to be retrieved for calculating glucose effects
    ///   - basalProfile: The daily schedule of basal insulin rates
    ///   - insulinSensitivitySchedule: The daily schedule of insulin sensitivity (ISF)
    ///   - overrideHistory: A history of overrides to be used when calculating glucose effects
    ///   - syncVersion: A version number for determining resolution in de-duplication
    ///   - lastPumpEventsReconciliation: The date the PumpManger last reconciled with the pump
    ///   - provenanceIdentifier: An id to store with new doses, indicating the provenance of the dose, usually the app's bundle identifier.
    ///   - test_currentDate: Used for testing to mock current time
    public init(
        healthStore: HKHealthStore,
        observeHealthKitSamplesFromOtherApps: Bool = true,
        storeSamplesToHealthKit: Bool = true,
        cacheStore: PersistenceController,
        observationEnabled: Bool = true,
        cacheLength: TimeInterval = 24 /* hours */ * 60 /* minutes */ * 60 /* seconds */,
        insulinModelProvider: InsulinModelProvider,
        longestEffectDuration: TimeInterval,
        basalProfile: BasalRateSchedule?,
        insulinSensitivitySchedule: InsulinSensitivitySchedule?,
        overrideHistory: TemporaryScheduleOverrideHistory? = nil,
        syncVersion: Int = 1,
        lastPumpEventsReconciliation: Date? = nil,
        provenanceIdentifier: String,
        test_currentDate: Date? = nil
    ) {
        self.insulinDeliveryStore = InsulinDeliveryStore(
            healthStore: healthStore,
            observeHealthKitSamplesFromOtherApps: observeHealthKitSamplesFromOtherApps,
            storeSamplesToHealthKit: storeSamplesToHealthKit,
            cacheStore: cacheStore,
            observationEnabled: observationEnabled,
            cacheLength: cacheLength,
            provenanceIdentifier: provenanceIdentifier,
            test_currentDate: test_currentDate
        )
        self.lockedInsulinSensitivitySchedule = Locked(insulinSensitivitySchedule)
        self.lockedInsulinModelProvider = Locked(insulinModelProvider)
        self.longestEffectDuration = longestEffectDuration
        self.lockedBasalProfile = Locked(basalProfile)
        self.overrideHistory = overrideHistory
        self.persistenceController = cacheStore
        self.cacheLength = cacheLength
        self.syncVersion = syncVersion
        self.lockedLastPumpEventsReconciliation = Locked(lastPumpEventsReconciliation)

        self.pumpEventQueryAfterDate = cacheStartDate

        persistenceController.onReady { (error) -> Void in
            guard error == nil else {
                return
            }

            self.persistenceController.managedObjectContext.perform {
                // Find the newest PumpEvent date we have
                let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                request.predicate = NSPredicate(format: "mutable != true")
                request.fetchLimit = 1

                if let events = try? self.persistenceController.managedObjectContext.fetch(request), let lastEvent = events.first {
                    self.pumpEventQueryAfterDate = lastEvent.date
                }

                // Validate the state of the stored reservoir data.
                self.validateReservoirContinuity()
            }
        }
    }

    /// Clears all pump data from the on-disk store.
    ///
    /// Calling this method may result in data loss, as there is no check to ensure data has been synced first.
    ///
    /// - Parameter completion: A closure to call after the reset has completed
    public func resetPumpData(completion: ((_ error: DoseStoreError?) -> Void)? = nil) {
        log.info("Resetting all cached pump data")
        deleteAllPumpEvents { (error) in
            self.deleteAllReservoirValues { (error) in
                completion?(error)
            }
        }
    }

    private let persistenceController: PersistenceController

    private let cacheLength: TimeInterval

    private var purgeableValuesPredicate: NSPredicate {
        return NSPredicate(format: "date < %@", cacheStartDate as NSDate)
    }

    /// The maximum length of time to keep data around.
    /// Dose data is unprotected on disk, and should only remain persisted long enough to support dosing algorithms and until its persisted by the delegate.
    public var cacheStartDate: Date {
        return currentDate(timeIntervalSinceNow: -cacheLength)
    }

    private var recentStartDate: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: currentDate())!
    }

    internal func currentDate(timeIntervalSinceNow: TimeInterval = 0) -> Date {
        return insulinDeliveryStore.currentDate(timeIntervalSinceNow: timeIntervalSinceNow)
    }

    // MARK: - Reservoir Data

    /// The last-created reservoir object.
    private var lastStoredReservoirValue: StoredReservoirValue? {
        get {
            return lockedLastStoredReservoirValue.value
        }
        set {
            lockedLastStoredReservoirValue.value = newValue
        }
    }
    private let lockedLastStoredReservoirValue = Locked<StoredReservoirValue?>(nil)

    // The last-saved reservoir value
    public var lastReservoirValue: ReservoirValue? {
        return lastStoredReservoirValue
    }

    /// An incremental cache of temp basal doses based on reservoir records, used to avoid repeated work.
    ///
    /// *Access should be isolated to a managed object context block*
    private var recentReservoirNormalizedDoseEntriesCache: [DoseEntry]?

    /**
     *This method should only be called from within a managed object context block.*
     */
    private func clearReservoirNormalizedDoseCache() {
        recentReservoirNormalizedDoseEntriesCache = nil
    }

    /// Whether the current recent state of the stored reservoir data is considered
    /// continuous and reliable for the derivation of insulin effects
    ///
    /// *Access should be isolated to a managed object context block*
    private var areReservoirValuesValid = false


    // MARK: - Pump Event Data

    /// The earliest event date that should included in subsequent queries for pump event data.
    public private(set) var pumpEventQueryAfterDate: Date {
        get {
            return lockedPumpEventQueryAfterDate.value
        }
        set {
            lockedPumpEventQueryAfterDate.value = newValue
        }
    }
    private let lockedPumpEventQueryAfterDate = Locked<Date>(.distantPast)

    /// The last time the PumpManager reconciled events with the pump.
    public private(set) var lastPumpEventsReconciliation: Date? {
        get {
            return lockedLastPumpEventsReconciliation.value
        }
        set {
            lockedLastPumpEventsReconciliation.value = newValue
        }
    }
    private let lockedLastPumpEventsReconciliation: Locked<Date?>

    public var lastAddedPumpData: Date {
        return [lastReservoirValue?.startDate, lastPumpEventsReconciliation].compactMap { $0 }.max() ?? .distantPast
    }

    /// The date of the most recent pump prime event, if known.
    ///
    /// *Access should be isolated to a managed object context block*
    private var lastRecordedPrimeEventDate: Date? {
        get {
            if _lastRecordedPrimeEventDate == nil {
                if  let pumpEvents = try? self.getPumpEventObjects(
                        matching: NSPredicate(format: "type = %@", PumpEventType.prime.rawValue),
                        chronological: false,
                        limit: 1
                    ),
                    let firstEvent = pumpEvents.first
                {
                    _lastRecordedPrimeEventDate = firstEvent.date
                } else {
                    _lastRecordedPrimeEventDate = .distantPast
                }
            }

            return _lastRecordedPrimeEventDate
        }
        set {
            _lastRecordedPrimeEventDate = newValue
        }
    }
    private var _lastRecordedPrimeEventDate: Date?

}


// MARK: - Reservoir Operations
extension DoseStore {
    /// Validates the current reservoir data for reliability in glucose effect calculation at the specified date
    ///
    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameter date: The date to base the continuity calculation on. Defaults to now.
    /// - Returns: The array of reservoir data used in the calculation
    @discardableResult
    private func validateReservoirContinuity(at date: Date? = nil) -> [Reservoir] {
        let date = date ?? currentDate()

        // Consider any entries longer than 30 minutes, or with a value of 0, to be unreliable
        let maximumInterval = TimeInterval(minutes: 30)
        
        let continuityStartDate = date.addingTimeInterval(-longestEffectDuration)

        if  let recentReservoirObjects = try? self.getReservoirObjects(since: continuityStartDate - maximumInterval),
            let oldestRelevantReservoirObject = recentReservoirObjects.last
        {
            // Verify reservoir timestamps are continuous
            let areReservoirValuesContinuous = recentReservoirObjects.reversed().isContinuous(
                from: continuityStartDate,
                to: date,
                within: maximumInterval
            )
            
            // also make sure prime events don't exist withing the insulin action duration
            let primeEventExistsWithinInsulinActionDuration = (lastRecordedPrimeEventDate ?? .distantPast) >= oldestRelevantReservoirObject.startDate

            self.areReservoirValuesValid = areReservoirValuesContinuous && !primeEventExistsWithinInsulinActionDuration
            self.lastStoredReservoirValue = recentReservoirObjects.first?.storedReservoirValue

            return recentReservoirObjects
        }

        self.areReservoirValuesValid = false
        self.lastStoredReservoirValue = nil
        return []
    }

    /**
     Adds and persists a new reservoir value

     - parameter unitVolume: The reservoir volume, in units
     - parameter date:       The date of the volume reading
     - parameter completion: A closure called after the value was saved. This closure takes three arguments:
        - value:                    The new reservoir value, if it was saved
        - previousValue:            The last new reservoir value
        - areStoredValuesContinous: Whether the current recent state of the stored reservoir data is considered continuous and reliable for deriving insulin effects after addition of this new value.
        - error:                    An error object explaining why the value could not be saved
     */
    public func addReservoirValue(_ unitVolume: Double, at date: Date, completion: @escaping (_ value: ReservoirValue?, _ previousValue: ReservoirValue?, _ areStoredValuesContinuous: Bool, _ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform {
            // Perform some sanity checking of the new value against the most recent value.
            if let previousValue = self.lastReservoirValue {
                let isOutOfOrder = previousValue.endDate > date
                let isSameDate = previousValue.endDate == date
                let isConflicting = isSameDate && previousValue.unitVolume != unitVolume
                if isOutOfOrder || isConflicting {
                    self.log.error("Added inconsistent reservoir value of %{public}.3fU at %{public}@ after %{public}.3fU at %{public}@. Resetting.", unitVolume, String(describing: date), previousValue.unitVolume, String(describing: previousValue.endDate))

                    // If we're violating consistency of the previous value, reset.
                    do {
                        try self.purgeReservoirObjects()
                        self.clearReservoirNormalizedDoseCache()
                        self.validateReservoirContinuity()
                    } catch let error {
                        self.log.error("Error purging reservoir objects: %{public}@", String(describing: error))
                        completion(nil, nil, false, DoseStoreError(error: error as? PersistenceController.PersistenceControllerError))
                        return
                    }
                    // If no error on purge, continue with creation
                } else if isSameDate && previousValue.unitVolume == unitVolume {
                    // Ignore duplicate adds
                    self.log.error("Added duplicate reservoir value at %{public}@", String(describing: date))
                    completion(nil, previousValue, self.areReservoirValuesValid, nil)
                    return
                }
            }

            let reservoir = Reservoir(context: self.persistenceController.managedObjectContext)

            reservoir.volume = unitVolume
            reservoir.date = date

            let previousValue = self.lastStoredReservoirValue
            if let basalProfile = self.basalProfileApplyingOverrideHistory {
                var newValues: [StoredReservoirValue] = []

                if let previousValue = previousValue {
                    newValues.append(previousValue)
                }

                newValues.append(reservoir.storedReservoirValue)

                let newDoseEntries = newValues.doseEntries

                if self.recentReservoirNormalizedDoseEntriesCache != nil {
                    self.recentReservoirNormalizedDoseEntriesCache = self.recentReservoirNormalizedDoseEntriesCache!.filterDateRange(self.recentStartDate, nil)

                    self.recentReservoirNormalizedDoseEntriesCache! += newDoseEntries.annotated(with: basalProfile)
                }
            }

            // Remove reservoir objects older than our cache length
            try? self.purgeReservoirObjects(matching: self.purgeableValuesPredicate)
            // Trigger a re-evaluation of continuity and update self.lastStoredReservoirValue
            self.validateReservoirContinuity()

            self.persistenceController.save { (error) -> Void in
                var saveError: DoseStoreError?

                if let error = error {
                    saveError = DoseStoreError(error: error)
                }

                completion(
                    reservoir.storedReservoirValue,
                    previousValue,
                    self.areReservoirValuesValid,
                    saveError
                )

                NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
            }
        }
    }

    /// Retrieves reservoir values since the given date.
    ///
    /// - Parameters:
    ///   - startDate: The earliest reservoir record date to include
    ///   - limit: An optional limit to the number of values returned
    ///   - completion: A closure called after retrieval
    ///   - result: An array of reservoir values in reverse-chronological order
    public func getReservoirValues(since startDate: Date, limit: Int? = nil, completion: @escaping (_ result: DoseStoreResult<[ReservoirValue]>) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                let values = try self.getReservoirObjects(since: startDate, limit: limit).map { $0.storedReservoirValue }

                completion(.success(values))
            } catch let error as DoseStoreError {
                completion(.failure(error))
            } catch {
                assertionFailure()
            }
        }
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameters:
    ///   - startDate: The earliest reservoir record date to include
    ///   - limit: An optional limit to the number of objects returned
    /// - Returns: An array of reservoir managed objects, in reverse-chronological order
    /// - Throws: An error describing the failure to fetch objects
    private func getReservoirObjects(since startDate: Date, limit: Int? = nil) throws -> [Reservoir] {
        let request: NSFetchRequest<Reservoir> = Reservoir.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            return try persistenceController.managedObjectContext.fetch(request)
        } catch let fetchError as NSError {
            throw DoseStoreError.fetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
        }
    }

    /// Retrieves normalized dose values derived from reservoir readings
    ///
    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameters:
    ///   - start: The earliest date of entries to include
    ///   - end: The latest date of entries to include, defaulting to the distant future.
    /// - Returns: An array of normalized entries
    /// - Throws: A DoseStoreError describing a failure
    private func getNormalizedReservoirDoseEntries(start: Date, end: Date? = nil) throws -> [DoseEntry] {
        if let normalizedDoses = self.recentReservoirNormalizedDoseEntriesCache, let firstDoseDate = normalizedDoses.first?.startDate, firstDoseDate <= start {
            return normalizedDoses.filterDateRange(start, end)
        } else {
            guard let basalProfile = self.basalProfileApplyingOverrideHistory else {
                throw DoseStoreError.configurationError
            }

            let doses = try self.getReservoirObjects(since: start).reversed().doseEntries

            let normalizedDoses = doses.annotated(with: basalProfile)
            self.recentReservoirNormalizedDoseEntriesCache = normalizedDoses
            return normalizedDoses.filterDateRange(start, end)
        }
    }

    /**
     Deletes a persisted reservoir value

     - parameter value:         The value to delete
     - parameter completion:    A closure called after the value was deleted. This closure takes two arguments:
     - parameter deletedValues: An array of removed values
     - parameter error:         An error object explaining why the value could not be deleted
     */
    public func deleteReservoirValue(_ value: ReservoirValue, completion: @escaping (_ deletedValues: [ReservoirValue], _ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform {
            var deletedObjects = [ReservoirValue]()
            if  let storedValue = value as? StoredReservoirValue,
                let objectID = self.persistenceController.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: storedValue.objectIDURL),
                let object = try? self.persistenceController.managedObjectContext.existingObject(with: objectID)
            {
                self.persistenceController.managedObjectContext.delete(object)
                deletedObjects.append(storedValue)
                self.validateReservoirContinuity()
            }

            self.persistenceController.save { (error) in
                self.clearReservoirNormalizedDoseCache()
                completion(deletedObjects, DoseStoreError(error: error))
                NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
            }
        }
    }

    /// Deletes all persisted reservoir values
    ///
    /// - Parameter completion: A closure called after all the values are deleted. This closure takes a single argument:
    /// - Parameter error: An error explaining why the deletion failed
    public func deleteAllReservoirValues(_ completion: @escaping (_ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                self.log.info("Deleting all reservoir values")
                try self.purgeReservoirObjects()

                self.persistenceController.save { (error) in
                    self.clearReservoirNormalizedDoseCache()
                    self.validateReservoirContinuity()

                    completion(DoseStoreError(error: error))
                    NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
                }
            } catch let error as PersistenceController.PersistenceControllerError {
                completion(DoseStoreError(error: error))
            } catch {
                assertionFailure()
            }
        }
    }

    /**
     Removes reservoir objects older than the recency predicate, and re-evaluates the continuity of the remaining objects

     *This method should only be called from within a managed object context block.*

     - throws: PersistenceController.PersistenceControllerError.coreDataError if the delete request failed
     */
    private func purgeReservoirObjects(matching predicate: NSPredicate? = nil) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Reservoir.entity().name!)
        fetchRequest.predicate = predicate

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            if let result = try persistenceController.managedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult,
                let objectIDs = result.result as? [NSManagedObjectID],
                objectIDs.count > 0
            {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [persistenceController.managedObjectContext])
                self.validateReservoirContinuity()
            }
        } catch let error as NSError {
            throw PersistenceController.PersistenceControllerError.coreDataError(error)
        }
    }
}


// MARK: - Pump Event Operations
extension DoseStore {
    /**
     Adds and persists new pump events.
     
     Events are deduplicated by a unique constraint on `NewPumpEvent.getter:raw`.

     - parameter events: An array of new pump events. Pump events should have end times reflective of when delivery is actually expected to be finished, as doses that end prior to a reservoir reading are ignored when reservoir data is being used.
     - parameter lastReconciliation: The date that pump events were most recently reconciled against recorded pump history. Pump events are assumed to be reflective of delivery up until this point in time. If reservoir values are recorded after this time, they may be used to supplement event based delivery.
     - parameter completion: A closure called after the events are saved. The closure takes a single argument:
     - parameter error: An error object explaining why the events could not be saved.
     */
    public func addPumpEvents(_ events: [NewPumpEvent], lastReconciliation: Date?, completion: @escaping (_ error: DoseStoreError?) -> Void) {
        lastPumpEventsReconciliation = lastReconciliation

        guard events.count > 0 else {
            completion(nil)
            return
        }

        for event in events {
            if let dose = event.dose {
                self.log.debug("Add %@, isMutable=%@", String(describing: dose), String(describing: event.isMutable))
            }
        }

        persistenceController.managedObjectContext.perform {
            var lastFinalDate: Date?
            var firstMutableDate: Date?
            var primeValueAdded = false

            // Remove any stored mutable pumpEvents; any that are still valid should be included in events
            do {
                try self.purgePumpEventObjects(matching: NSPredicate(format: "mutable == true"))
            } catch let error {
                completion(DoseStoreError(error: .coreDataError(error as NSError)))
                return
            }
            
            // Remove old doses
            self.purgePumpEventObjects(before: self.cacheStartDate, completion: { error in
                if let error = error {
                    self.log.error("Error purging PumpEvent objects: %{public}@", String(describing: error))
                }
            })

            // There is no guarantee of event ordering, so we must search the entire array to find key date boundaries.

            for event in events {
                if case .prime? = event.type {
                    primeValueAdded = true
                }

                if event.isMutable {
                    firstMutableDate = min(event.date, firstMutableDate ?? event.date)
                } else {
                    lastFinalDate = max(event.date, lastFinalDate ?? event.date)
                }

                let object = PumpEvent(context: self.persistenceController.managedObjectContext)

                object.date = event.date
                object.raw = event.raw
                object.title = event.title
                object.type = event.type
                object.mutable = event.isMutable
                object.dose = event.dose
                object.alarmType = event.alarmType
            }

            // Only change pumpEventQueryAfterDate if we received new finalized records.
            if let finalDate = lastFinalDate {
                if let mutableDate = firstMutableDate, mutableDate < finalDate {
                    self.pumpEventQueryAfterDate = mutableDate
                } else {
                    self.pumpEventQueryAfterDate = finalDate
                }
            }

            if primeValueAdded {
                self.lastRecordedPrimeEventDate = nil
                self.validateReservoirContinuity()
            }

            self.persistenceController.save { (error) -> Void in
                self.syncPumpEventsToInsulinDeliveryStore() { _ in
                    completion(DoseStoreError(error: error))
                    self.delegate?.doseStoreHasUpdatedPumpData(self)
                    NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
                }
            }
        }
    }

    public func deletePumpEvent(_ event: PersistedPumpEvent, completion: @escaping (_ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform {

            if  let objectID = self.persistenceController.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: event.objectIDURL),
                let object = try? self.persistenceController.managedObjectContext.existingObject(with: objectID)
            {
                self.persistenceController.managedObjectContext.delete(object)
            }

            // Reset the latest query date to the newest PumpEvent
            let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.predicate = NSPredicate(format: "mutable != true")
            request.fetchLimit = 1

            if let events = try? self.persistenceController.managedObjectContext.fetch(request),
                let lastEvent = events.first
            {
                self.pumpEventQueryAfterDate = lastEvent.date
            } else {
                self.pumpEventQueryAfterDate = self.cacheStartDate
            }

            self.persistenceController.save { (error) in
                completion(DoseStoreError(error: error))
                NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
                
                self.lastRecordedPrimeEventDate = nil
                self.validateReservoirContinuity()
            }
        }
    }

    /// Deletes all persisted pump events
    ///
    /// - Parameter completion: A closure called after all the events are deleted. This closure takes a single argument:
    /// - Parameter error: An error explaining why the deletion failed
    public func deleteAllPumpEvents(_ completion: @escaping (_ error: DoseStoreError?) -> Void) {
        syncPumpEventsToInsulinDeliveryStore { (error) in
            if let error = error {
                self.log.error("Error performing final sync to insulin delivery store before deleteAllPumpEvents: %{public}@", String(describing: error))
            }

            self.persistenceController.managedObjectContext.perform {
                do {
                    self.log.info("Deleting all pump events")
                    try self.purgePumpEventObjects()

                    self.persistenceController.save { (error) in
                        self.pumpEventQueryAfterDate = self.cacheStartDate
                        self.lastPumpEventsReconciliation = nil
                        self.lastRecordedPrimeEventDate = nil

                        completion(DoseStoreError(error: error))
                        NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
                    }
                } catch let error as PersistenceController.PersistenceControllerError {
                    completion(DoseStoreError(error: error))
                } catch {
                    assertionFailure()
                }
            }
        }
    }

    /**
     Adds and persists doses
     - parameter doses: An array of dose entries to add.
     - parameter completion: A closure called after the doses are saved. The closure takes a single argument:
     - parameter error: An error object explaining why the doses could not be saved.
     */
    public func addDoses(_ doses: [DoseEntry], completion: @escaping (_ error: Error?) -> Void) {
        guard doses.count > 0 else {
            completion(nil)
            return
        }

        self.persistenceController.save { (error) -> Void in
            self.insulinDeliveryStore.addDoseEntries(doses, from: nil, syncVersion: self.syncVersion) { (result) in
                switch result {
                case .success:
                    completion(nil)
                    self.syncPumpEventsToInsulinDeliveryStore { error in
                        completion(error)
                        NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
                    }
                case .failure(let error):
                    self.log.error("Error adding dose: %{public}@", String(describing: error))
                    completion(error)
                }
            }
        }
    }

    /// Deletes one particular manually entered dose from the store
    ///
    /// - Parameter dose: Dose to delete.
    /// - Parameter completion: A closure called after the event deleted. This closure takes a single argument:
    /// - Parameter success: True if dose was successfully deleted
    public func deleteDose(_ dose: DoseEntry, completion: @escaping (_ error: DoseStoreError?) -> Void) {
        guard let syncIdentifier = dose.syncIdentifier else {
            self.log.error("Unable to delete PersistedManualEntryDose: no syncIdentifier")
            completion(DoseStoreError.fetchError(description: "Unable to delete dose: syncIdentifier is missing", recoverySuggestion: "File an issue report in Github"))
            return
        }
        insulinDeliveryStore.deleteDose(bySyncIdentifier: syncIdentifier) { (error) in
            if let error = error {
                completion(DoseStoreError.persistenceError(description: error, recoverySuggestion: nil))
            } else {
                completion(nil)
                NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
            }
        }
    }

    /// Deletes all manually entered doses
    ///
    /// - Parameter completion: A closure called after all the events are deleted. This closure takes a single argument:
    /// - Parameter error: An error explaining why the deletion failed
    public func deleteAllManuallyEnteredDoses(_ completion: @escaping (_ error: DoseStoreError?) -> Void) {
        self.persistenceController.managedObjectContext.perform {
            do {
                self.log.info("Deleting all manually entered doses")
                try self.purgeManuallyEnteredDoses()

                self.persistenceController.save { (error) in

                    completion(DoseStoreError(error: error))
                    NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
                }
            } catch let error as PersistenceController.PersistenceControllerError {
                completion(DoseStoreError(error: error))
            } catch {
                assertionFailure()
            }
        }
    }

    /**
     Removes all manually entered doses.
     
     *This method should only be called from within a managed object context block.*
     - throws: PersistenceController.PersistenceControllerError.coreDataError if the delete request failed
     */
    private func purgeManuallyEnteredDoses() throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: CachedInsulinDeliveryObject.entity().name!)
        // Only delete manually entered doses
        let typePredicate = NSPredicate(format: "manuallyEntered == YES")
        fetchRequest.predicate = typePredicate

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            if let result = try persistenceController.managedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult,
                let objectIDs = result.result as? [NSManagedObjectID],
                objectIDs.count > 0
            {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [persistenceController.managedObjectContext])
                persistenceController.managedObjectContext.refreshAllObjects()
            }
        } catch let error as NSError {
            throw PersistenceController.PersistenceControllerError.coreDataError(error)
        }
    }


    /// Attempts to store doses from pump events to insulin delivery store
    private func syncPumpEventsToInsulinDeliveryStore(after start: Date? = nil, completion: @escaping (_ error: Error?) -> Void) {
        insulinDeliveryStore.getLastBasalEndDate { (result) in
            switch result {
            case .success(let date):
                // Limit the query behavior to 24 hours
                let date = max(date, self.recentStartDate)
                self.savePumpEventsToInsulinDeliveryStore(after: start ?? date, completion: completion)
            case .failure(let error):
                completion(error)
            }
        }
    }

    /// Processes and saves dose events on or after the given date to insulin delivery store
    ///
    /// - Parameters:
    ///   - start: The date on and after which to include doses
    ///   - completion: A closure called on completion
    ///   - error: An error if one ocurred during processing or saving
    private func savePumpEventsToInsulinDeliveryStore(after start: Date, completion: @escaping (_ error: Error?) -> Void) {
        getPumpEventDoseEntriesForSavingToInsulinDeliveryStore(startingAt: start) { (result) in
            switch result {
            case .success(let doses):
                guard doses.count > 0 else {
                    completion(nil)
                    return
                }

                for dose in doses {
                    self.log.debug("Adding dose to insulin delivery store: %@", String(describing: dose))
                }

                self.insulinDeliveryStore.addDoseEntries(doses, from: self.device, syncVersion: self.syncVersion) { (result) in
                    switch result {
                    case .success:
                        completion(nil)
                    case .failure(let error):
                        self.log.error("Error adding doses: %{public}@", String(describing: error))
                        completion(error)
                    }
                }
            case .failure(let error):
                completion(error)
            }
        }
    }

    /// Fetches a timeline of doses, filling in gaps between delivery changes with the scheduled basal delivery
    /// if the pump doesn't already handle this
    ///
    /// - Parameters:
    ///   - start: The date on and after which to include doses
    ///   - completion: A closure called on completion
    ///   - result: The doses along with schedule basal
    private func getPumpEventDoseEntriesForSavingToInsulinDeliveryStore(startingAt: Date, completion: @escaping (_ result: DoseStoreResult<[DoseEntry]>) -> Void) {
        // Can't store to insulin delivery store if we don't know end of reconciled range, or if we already have doses after the end
        guard let endingAt = lastPumpEventsReconciliation, endingAt > startingAt else {
            completion(.success([]))
            return
        }

        self.persistenceController.managedObjectContext.perform {
            let doses: [DoseEntry]
            do {
                doses = try self.getNormalizedPumpEventDoseEntriesForSavingToInsulinDeliveryStore(basalStart: startingAt, end: self.currentDate())
            } catch let error as DoseStoreError {
                self.log.error("Error while fetching doses to add to insulin delivery store: %{public}@", String(describing: error))
                completion(.failure(error))
                return
            } catch {
                assertionFailure()
                return
            }
            
            guard !doses.isEmpty else
            {
                completion(.success([]))
                return
            }

            guard let basalSchedule = self.basalProfileApplyingOverrideHistory else {
                self.log.error("Can't save %d doses to insulin delivery store because no basal profile is configured", doses.count)
                completion(.failure(DoseStoreError.configurationError))
                return
            }

            let reconciledDoses = doses.overlayBasalSchedule(basalSchedule, startingAt: startingAt, endingAt: endingAt, insertingBasalEntries: !self.pumpRecordsBasalProfileStartEvents)
            completion(.success(reconciledDoses))
        }
    }
    
    /// Fetches manually entered doses.
    ///
    /// - Parameter startDate: The earliest dose startDate to include
    /// - Returns: An array of manually entered dose managed objects, in reverse-chronological order
    /// - Throws: An error describing the failure to fetch objects
    public func getManuallyEnteredDoses(since startDate: Date, completion: @escaping (_ result: DoseStoreResult<[DoseEntry]>) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                let events = try self.getManuallyEnteredDoses(
                    matching: NSPredicate(format: "startDate >= %@", startDate as NSDate),
                    chronological: false
                )

                completion(.success(events))
            } catch let error as DoseStoreError {
                completion(.failure(error))
            } catch {
                assertionFailure()
            }
        }


    }

    /// Fetches manually entered doses.
    /// *This method should only be called from within a managed object context block.*
    ///
    /// Objects are ordered by date using the DoseType sort ordering as a tiebreaker for stability
    ///
    /// - Parameters:
    ///   - predicate: The predicate to apply to the objects
    ///   - chronological: Whether to return the objects in chronological or reverse-chronological order
    /// - Returns: An array of pump events in the specified order by date
    /// - Throws: An error describing the failure to fetch objects
    private func getManuallyEnteredDoses(matching predicate: NSPredicate, chronological: Bool, limit: Int? = nil) throws -> [DoseEntry] {
        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()

        let sourcePredicate = NSPredicate(format: "manuallyEntered == YES")
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sourcePredicate])
        request.predicate = compoundPredicate
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: chronological)]

        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            return try persistenceController.managedObjectContext.fetch(request).sorted(by: { (lhs, rhs) -> Bool in
                let (first, second) = chronological ? (lhs, rhs) : (rhs, lhs)

                return first.startDate < second.startDate
            }).compactMap{ $0.dose }
        } catch let fetchError as NSError {
            throw DoseStoreError.fetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
        }
    }

    /// Retrieves pump event values since the given date.
    ///
    /// - Parameters:
    ///   - startDate: The earliest pump event date to include
    ///   - completion: A closure called after retrieval
    ///   - result: An array of pump event values in reverse-chronological order
    public func getPumpEventValues(since startDate: Date, completion: @escaping (_ result: DoseStoreResult<[PersistedPumpEvent]>) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                let events = try self.getPumpEventObjects(since: startDate).map { $0.persistedPumpEvent }

                completion(.success(events))
            } catch let error as DoseStoreError {
                completion(.failure(error))
            } catch {
                assertionFailure()
            }
        }
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameter startDate: The earliest pump event date to include
    /// - Returns: An array of pump event managed objects, in reverse-chronological order
    /// - Throws: An error describing the failure to fetch objects
    private func getPumpEventObjects(since startDate: Date) throws -> [PumpEvent] {
        return try getPumpEventObjects(
            matching: NSPredicate(format: "date >= %@", startDate as NSDate),
            chronological: false
        )
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// Objects are ordered by date using the DoseType sort ordering as a tiebreaker for stability
    ///
    /// - Parameters:
    ///   - predicate: The predicate to apply to the objects
    ///   - chronological: Whether to return the objects in chronological or reverse-chronological order
    /// - Returns: An array of pump events in the specified order by date
    /// - Throws: An error describing the failure to fetch objects
    private func getPumpEventObjects(matching predicate: NSPredicate, chronological: Bool, limit: Int? = nil) throws -> [PumpEvent] {
        let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: chronological)]

        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            return try persistenceController.managedObjectContext.fetch(request).sorted(by: { (lhs, rhs) -> Bool in
                let (first, second) = chronological ? (lhs, rhs) : (rhs, lhs)

                if  first.startDate == second.startDate,
                    let firstType = first.type, let secondType = second.type
                {
                    return firstType.sortOrder < secondType.sortOrder
                } else {
                    return first.startDate < second.startDate
                }
            })
        } catch let fetchError as NSError {
            throw DoseStoreError.fetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
        }
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameters:
    ///   - start: The earliest dose end date to include
    ///   - end: The latest dose start date to include
    /// - Returns: An array of doses from pump events
    /// - Throws: An error describing the failure to fetch objects
    private func getNormalizedPumpEventDoseEntries(start: Date, end: Date? = nil) throws -> [DoseEntry] {
        guard let basalProfile = self.basalProfileApplyingOverrideHistory else {
            throw DoseStoreError.configurationError
        }

        let queryStart = start.addingTimeInterval(-pumpEventReconciliationWindow)

        let doses = try getPumpEventObjects(
            matching: NSPredicate(format: "date >= %@ && doseType != nil", queryStart as NSDate),
            chronological: true
        ).compactMap({ $0.dose })
        let normalizedDoses = doses.reconciled().annotated(with: basalProfile)

        return normalizedDoses.filterDateRange(start, end)
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Returns: An array of doses from pump events that were marked mutable
    /// - Throws: An error describing the failure to fetch objects
    private func getNormalizedMutablePumpEventDoseEntries(start: Date) throws -> [DoseEntry] {
        guard let basalProfile = self.basalProfileApplyingOverrideHistory else {
            throw DoseStoreError.configurationError
        }

        let doses = try getPumpEventObjects(
            matching: NSPredicate(format: "mutable == true && doseType != nil"),
            chronological: true
            ).compactMap({ $0.dose })
        let normalizedDoses = doses.filterDateRange(start, nil).reconciled().annotated(with: basalProfile)
        return normalizedDoses.map { $0.trimmed(from: start) }
    }


    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameters:
    ///   - basalStart: The earliest basal dose start date to include
    ///   - end: The latest dose end date to include
    /// - Returns: An array of doses from pump events
    /// - Throws: An error describing the failure to fetch objects
    private func getNormalizedPumpEventDoseEntriesForSavingToInsulinDeliveryStore(basalStart: Date, end: Date) throws -> [DoseEntry] {
        guard let basalProfile = self.basalProfileApplyingOverrideHistory else {
            throw DoseStoreError.configurationError
        }

        // Make sure we look far back enough to have prior temp basal records to reconcile
        // resumption of temp basal after suspend/resume.
        let queryStart = basalStart.addingTimeInterval(-pumpEventReconciliationWindow)

        let afterBasalStart = NSPredicate(format: "date >= %@ && doseType != nil && mutable == false", queryStart as NSDate)
        let allBoluses = NSPredicate(format: "date >= %@ && doseType == %@ && mutable == false", recentStartDate as NSDate, DoseType.bolus.rawValue)

        let doses = try getPumpEventObjects(
            matching: NSCompoundPredicate(orPredicateWithSubpredicates: [afterBasalStart, allBoluses]),
            chronological: true
        ).compactMap({ $0.dose })
        // Ignore any doses which have not yet ended by the specified date.
        // Also, since we are retrieving dosing history older than basalStart for
        // reconciliation purposes, we need to filter that out after reconciliation.
        let normalizedDoses = doses.reconciled().filter({ $0.endDate <= end }).annotated(with: basalProfile).filter({ $0.startDate >= basalStart || $0.type == .bolus })

        return normalizedDoses
    }

    public func purgePumpEventObjects(before date: Date, completion: (Error?) -> Void) {
        do {
            let count = try purgePumpEventObjects(matching: NSPredicate(format: "date < %@", date as NSDate))
            self.log.info("Purged %d PumpEvents", count)
            completion(nil)
        } catch let error {
            self.log.error("Unable to purge PumpEvents: %{public}@", String(describing: error))
            completion(error)
        }
    }

    /**
     Removes uploaded pump event objects older than the recency predicate

     *This method should only be called from within a managed object context block.*

     - throws: A core data exception if the delete request failed
     */
    @discardableResult
    private func purgePumpEventObjects(matching predicate: NSPredicate? = nil) throws -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: PumpEvent.entity().name!)
        fetchRequest.predicate = predicate

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        if  let result = try persistenceController.managedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult,
            let objectIDs = result.result as? [NSManagedObjectID],
            objectIDs.count > 0
        {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [persistenceController.managedObjectContext])
            persistenceController.managedObjectContext.refreshAllObjects()
            return objectIDs.count
        }

        return 0
    }
}


extension DoseStore {
    /// Retrieves dose entries normalized to the current basal schedule, for visualization purposes.
    ///
    /// Doses are derived from pump events if they've been updated within the last 15 minutes or reservoir data is incomplete.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - start: The earliest endDate of entries to retrieve
    ///   - end: The latest startDate of entries to retrieve, if provided
    ///   - completion: A closure called once the entries have been retrieved
    ///   - result: An array of dose entries, in chronological order by startDate
    public func getNormalizedDoseEntries(start: Date, end: Date? = nil, completion: @escaping (_ result: DoseStoreResult<[DoseEntry]>) -> Void) {
        insulinDeliveryStore.getDoseEntries(start: start, end: end) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(.persistenceError(description: error.localizedDescription, recoverySuggestion: nil)))
            case .success(let insulinDeliveryDoses):
                let filteredStart = max(self.lastPumpEventsReconciliation ?? start, start)

                self.persistenceController.managedObjectContext.perform {
                    do {
                        let doses: [DoseEntry]

                        // Reservoir data is used only if it's continuous and the pumpmanager hasn't reconciled since the last reservoir reading
                        if self.areReservoirValuesValid, let reservoirEndDate = self.lastStoredReservoirValue?.startDate, reservoirEndDate > self.lastPumpEventsReconciliation ?? .distantPast {
                            let reservoirDoses = try self.getNormalizedReservoirDoseEntries(start: filteredStart, end: end)
                            let endOfReservoirData = self.lastStoredReservoirValue?.endDate ?? .distantPast
                            let mutableDoses = try self.getNormalizedMutablePumpEventDoseEntries(start: endOfReservoirData)
                            doses = insulinDeliveryDoses + reservoirDoses.map({ $0.trimmed(from: filteredStart) }) + mutableDoses
                        } else {
                            // Includes mutable doses.
                            doses = insulinDeliveryDoses.appendedUnion(with: try self.getNormalizedPumpEventDoseEntries(start: filteredStart, end: end))
                        }
                        completion(.success(doses))
                    } catch let error as DoseStoreError {
                        completion(.failure(error))
                    } catch {
                        assertionFailure()
                    }
                }
            }
        }
    }

    /// Retrieves the maximum insulin on-board value from the two timeline values nearest to the specified date
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - date: The date of the value to retrieve
    ///   - completion: A closure called once the value has been retrieved
    ///   - result: The insulin on-board value
    public func insulinOnBoard(at date: Date, completion: @escaping (_ result: DoseStoreResult<InsulinValue>) -> Void) {
        getInsulinOnBoardValues(start: date.addingTimeInterval(.minutes(-5)), end: date.addingTimeInterval(.minutes(5))) { (result) -> Void in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let values):
                let closest = values.allElementsAdjacent(to: date)

                // Return the larger of the two bounding values, for the scenario when a bolus
                // was scheduled between the two values; we want to return the later, larger value
                guard let maxValue = closest.max(by: { return $0.value < $1.value }) else {
                    // If we have no iob values in the store, and did not encounter an error, return 0
                    completion(.success(InsulinValue(startDate: date, value: 0)))
                    return
                }

                completion(.success(maxValue))
            }
        }
    }

    /// Retrieves a timeline of unabsorbed insulin values.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - basalDosingEnd: The date at which continuing doses should be assumed to be cancelled
    ///   - completion: A closure called once the values have been retrieved
    ///   - result: An array of insulin values, in chronological order
    public func getInsulinOnBoardValues(start: Date, end: Date? = nil, basalDosingEnd: Date? = nil, completion: @escaping (_ result: DoseStoreResult<[InsulinValue]>) -> Void) {
        
        // To properly know IOB at startDate, we need to go back another DIA hours
        let doseStart = start.addingTimeInterval(-longestEffectDuration)
        getNormalizedDoseEntries(start: doseStart, end: end) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let doses):
                let trimmedDoses = doses.map { $0.trimmed(to: basalDosingEnd) }
                let insulinOnBoard = trimmedDoses.insulinOnBoard(insulinModelProvider: self.insulinModelProvider, longestEffectDuration: self.longestEffectDuration)
                completion(.success(insulinOnBoard.filterDateRange(start, end)))
            }
        }
    }

    /// Retrieves a timeline of effect on blood glucose from doses
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - start: The earliest date of effects to retrieve
    ///   - end: The latest date of effects to retrieve, if provided
    ///   - basalDosingEnd: The date at which continuing doses should be assumed to be cancelled
    ///   - completion: A closure called once the effects have been retrieved
    ///   - result: An array of effects, in chronological order
    public func getGlucoseEffects(start: Date, end: Date? = nil, basalDosingEnd: Date? = Date(), completion: @escaping (_ result: DoseStoreResult<[GlucoseEffect]>) -> Void) {
        guard let insulinSensitivitySchedule = self.insulinSensitivityScheduleApplyingOverrideHistory else {
            completion(.failure(.configurationError))
            return
        }

        // To properly know glucose effects at startDate, we need to go back another DIA hours
        let doseStart = start.addingTimeInterval(-longestEffectDuration)
        getNormalizedDoseEntries(start: doseStart, end: end) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let doses):
                let trimmedDoses = doses.map { (dose) -> DoseEntry in
                    guard dose.type != .bolus else {
                        return dose
                    }
                    return dose.trimmed(to: basalDosingEnd)
                }

                let glucoseEffects = trimmedDoses.glucoseEffects(insulinModelProvider: self.insulinModelProvider, longestEffectDuration: self.longestEffectDuration, insulinSensitivity: insulinSensitivitySchedule)
                completion(.success(glucoseEffects.filterDateRange(start, end)))
            }
        }
    }

    /// Retrieves the estimated total number of units delivered since the specified date.
    ///
    /// - Parameters:
    ///   - startDate: The date after which delivery should be calculated
    ///   - completion: A closure called once the total has been retrieved with arguments:
    ///   - result: The total units delivered and the date of the first dose
    public func getTotalUnitsDelivered(since startDate: Date, completion: @escaping (_ result: DoseStoreResult<InsulinValue>) -> Void) {
        persistenceController.managedObjectContext.perform {

            self.getNormalizedDoseEntries(start: startDate) { (result) in
                switch result {
                case .success(let doses):
                    let trimmedDoses = doses.map { $0.trimmed(from: startDate, to: self.currentDate())}
                    let result = InsulinValue(
                        startDate: startDate,
                        value: trimmedDoses.totalDelivery
                    )

                    completion(.success(result))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}

extension DoseStore {
    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completion: The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completion: @escaping (_ report: String) -> Void) {
        var report: [String] = [
            "## DoseStore",
            "",
            "* insulinModelProvider: \(String(reflecting: insulinModelProvider))",
            "* basalProfile: \(basalProfile?.debugDescription ?? "")",
            "* basalProfileApplyingOverrideHistory \(basalProfileApplyingOverrideHistory?.debugDescription ?? "nil")",
            "* insulinSensitivitySchedule: \(insulinSensitivitySchedule?.debugDescription ?? "")",
            "* insulinSensitivityScheduleApplyingOverrideHistory \(insulinSensitivityScheduleApplyingOverrideHistory?.debugDescription ?? "nil")",
            "* overrideHistory: \(overrideHistory.map(String.init(describing:)) ?? "nil")",
            "* egpSchedule: \(egpSchedule?.debugDescription ?? "nil")",
            "* areReservoirValuesValid: \(areReservoirValuesValid)",
            "* lastPumpEventsReconciliation: \(String(describing: lastPumpEventsReconciliation))",
            "* lastStoredReservoirValue: \(String(describing: lastStoredReservoirValue))",
            "* pumpEventQueryAfterDate: \(pumpEventQueryAfterDate)",
            "* lastRecordedPrimeEventDate: \(String(describing: lastRecordedPrimeEventDate))",
            "* pumpRecordsBasalProfileStartEvents: \(pumpRecordsBasalProfileStartEvents)",
            "* device: \(String(describing: device))",
        ]

        insulinOnBoard(at: currentDate()) { (result) in
            report.append("")

            switch result {
            case .failure(let error):
                report.append("* insulinOnBoard: \(error)")
            case .success(let value):
                report.append("* insulinOnBoard: \(String(describing: value))")
            }

            self.getReservoirValues(since: Date.distantPast) { (result) in
                report.append("")
                report.append("### getReservoirValues")

                switch result {
                case .failure(let error):
                    report.append("Error: \(error)")
                case .success(let values):
                    report.append("")
                    report.append("* Reservoir(startDate, unitVolume)")
                    for value in values {
                        report.append("* \(value.startDate), \(value.unitVolume)")
                    }
                }

                self.getPumpEventValues(since: Date.distantPast) { (result) in
                    report.append("")
                    report.append("### getPumpEventValues")

                    var firstPumpEventDate = self.cacheStartDate

                    switch result {
                    case .failure(let error):
                        report.append("Error: \(error)")
                    case .success(let values):
                        report.append("")

                        if let firstEvent = values.last {
                            firstPumpEventDate = firstEvent.date
                        }

                        for value in values {
                            report.append("* \(value)")
                        }
                    }

                    self.getNormalizedDoseEntries(start: firstPumpEventDate) { (result) in
                        report.append("")
                        report.append("### getNormalizedDoseEntries")

                        switch result {
                        case .failure(let error):
                            report.append("Error: \(error)")
                        case .success(let entries):
                            report.append("")
                            for entry in entries {
                                report.append("* \(entry)")
                            }
                        }

                        self.getPumpEventDoseEntriesForSavingToInsulinDeliveryStore(startingAt: firstPumpEventDate, completion: { (result) in

                            report.append("")
                            report.append("### getNormalizedPumpEventDoseEntriesOverlaidWithBasalEntries")

                            switch result {
                            case .failure(let error):
                                report.append("Error: \(error)")
                            case .success(let entries):
                                report.append("")
                                for entry in entries {
                                    report.append("* \(entry)")
                                }
                            }
                            
                            self.getManuallyEnteredDoses(since: firstPumpEventDate) { (result) in
                                report.append("")
                                report.append("### getManuallyEnteredDoses")

                                switch result {
                                case .failure(let error):
                                    report.append("Error: \(error)")
                                case .success(let entries):
                                    report.append("")
                                    for entry in entries {
                                        report.append("* \(entry)")
                                    }
                                }
                                
                                self.insulinDeliveryStore.generateDiagnosticReport { (result) in
                                    report.append("")
                                    report.append(result)

                                    report.append("")
                                    completion(report.joined(separator: "\n"))
                                }
                            }
                        })
                    }
                }
            }
        }
    }
}

extension DoseStore {

    public struct QueryAnchor: RawRepresentable {

        public typealias RawValue = [String: Any]

        internal var modificationCounter: Int64
        internal var scheduledBasalStartDate: Date?

        public init() {
            self.modificationCounter = 0
            self.scheduledBasalStartDate = nil
        }

        public init?(rawValue: RawValue) {
            guard let modificationCounter = rawValue["modificationCounter"] as? Int64 else {
                return nil
            }
            self.modificationCounter = modificationCounter
            self.scheduledBasalStartDate = rawValue["scheduledBasalStartDate"] as? Date
        }

        public var rawValue: RawValue {
            var rawValue: RawValue = [:]
            rawValue["modificationCounter"] = modificationCounter
            rawValue["scheduledBasalStartDate"] = scheduledBasalStartDate
            return rawValue
        }
    }

    public enum PumpQueryResult {
        case success(QueryAnchor, [SyncPumpEvent])
        case failure(Error)
    }
    
    public func executePumpQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (PumpQueryResult) -> Void) {
        var queryAnchor = queryAnchor ?? QueryAnchor()
        var queryError: Error?

        guard limit > 0 else {
            completion(.success(queryAnchor, []))
            return
        }

        var pumpEvents = [SyncPumpEventWithModificationCounter]()

        // Get the next page of pump events
        persistenceController.managedObjectContext.performAndWait {
            let storedRequest: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()

            storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
            storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
            storedRequest.fetchLimit = limit

            do {
                pumpEvents = try self.persistenceController.managedObjectContext.fetch(storedRequest).compactMap { $0.syncPumpEventWithModificationCounter }
                pumpEvents.sort(by: { SyncPumpEventWithModificationCounter.sort($0, $1) } )
            } catch {
                queryError = error
            }
        }

        if let queryError = queryError {
            completion(.failure(queryError))
            return
        }

        // Determine the potential schedule basal end date used to query the insulin delivery store. Find the date of the
        // latest pump event that can end a scheduled basal, namely either a resume or temp basal event.
        let scheduledBasalEndDate = (pumpEvents.count == limit) ? pumpEvents.filter({ $0.delineatesScheduledBasal }).last?.endDate : nil

        // Get the doses within the pump event window
        insulinDeliveryStore.getDoseEntries(start: queryAnchor.scheduledBasalStartDate, end: scheduledBasalEndDate, limit: limit, inclusive: false) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let doses):
                var doseEvents = doses.compactMap { $0.syncPumpEventWithModificationCounter }
                doseEvents.sort(by: { SyncPumpEventWithModificationCounter.sort($0, $1) })

                var events: [SyncPumpEventWithModificationCounter] = []

                // Walk the two sets of events and reconcile. As the events are sorted by start date, the event with the earlier
                // start date gets added. If the events have the same start date, then reconcile based upon type.
                var pumpEventIndex = 0
                var doseEventIndex = 0
                while true {
                    if let pumpEvent = pumpEvents[safe: pumpEventIndex], let doseEvent = doseEvents[safe: doseEventIndex] {
                        switch pumpEvent.startDate.compare(doseEvent.startDate) {
                        case .orderedSame:
                            switch pumpEvent.syncPumpEvent.type {
                            case .alarm, .alarmClear, .prime, .resume, .rewind, .suspend:
                                events.append(pumpEvent)
                                pumpEventIndex += 1
                            case .basal, .tempBasal:
                                // A single basal pump event can be split into multiple basal dose events to account for changes to underlying scheduled basal
                                if pumpEvent.endDate > doseEvent.endDate {
                                    var splitEvents: [SyncPumpEventWithModificationCounter] = []
                                    while let doseEvent = doseEvents[safe: doseEventIndex], pumpEvent.endDate >= doseEvent.endDate {
                                        splitEvents.append(doseEvent)
                                        doseEventIndex += 1
                                    }
                                    events.append(contentsOf: splitEvents.map { SyncPumpEventWithModificationCounter($0.syncPumpEvent, modificationCounter: pumpEvent.modificationCounter) })
                                    pumpEventIndex += 1
                                } else {
                                    events.append(SyncPumpEventWithModificationCounter(doseEvent.syncPumpEvent, modificationCounter: pumpEvent.modificationCounter))
                                    doseEventIndex += 1
                                    pumpEventIndex += 1
                                }
                            case .bolus:
                                events.append(pumpEvent)
                                doseEventIndex += 1
                                pumpEventIndex += 1
                            }
                        case .orderedAscending:
                            events.append(pumpEvent)
                            pumpEventIndex += 1
                        case .orderedDescending:
                            events.append(doseEvent)
                            doseEventIndex += 1
                        }
                    } else {

                        // No more events in one of the sets so just add the remainder of the events and stop
                        if pumpEventIndex < pumpEvents.endIndex {
                            events.append(contentsOf: pumpEvents[pumpEventIndex..<pumpEvents.endIndex])
                        }
                        if doseEventIndex < doseEvents.endIndex {
                            events.append(contentsOf: doseEvents[doseEventIndex..<doseEvents.endIndex])
                        }
                        break
                    }
                }

                // If the total number of events is larger than the limit, then trim down to size. However, to maintain a valid query
                // using the modification counter, the latest modification counter in the limit events MUST NOT be later than the
                // earliest modification counter in the extra events. If this is this case, then we need either reduce the limit
                // events or use all of the events.
                if events.count > limit {
                    let (limitEvents, extraEvents) = events.split(at: limit)

                    // Only care if there are modification counters in both the limit and extra events. If either is missing or
                    // the latest limit modification counter is earlier than the earliest extra modification counter, which indicates
                    // the events are in a valid modification counter order, then there is no modification counter issue.
                    if let limitModificationCounterLatest = limitEvents.compactMap({ $0.modificationCounter }).max(),
                       let extraModificationCounterEarliest = extraEvents.compactMap({ $0.modificationCounter }).min(),
                       limitModificationCounterLatest > extraModificationCounterEarliest {

                        // Otherwise, find the index of the first modification counter in the limit events that exceeds the earliest
                        // extra modification counter and as long as it isn't the first index, use up to that point. Otherwise, we have no
                        // choice but to use all of the events (highly unlikely unless an especially small limit). In theory,
                        // we could use part of the extra events, but that requires extra work and is not worth the effort considering
                        // the remote likelyhood of this last case.
                        if let limitIndex = limitEvents.firstIndex(where: { $0.modificationCounter.map { $0 > extraModificationCounterEarliest } == true }), limitIndex > 0 {
                            (events, _) = limitEvents.split(at: limitIndex)
                        }
                    } else {
                        events = limitEvents
                    }
                }

                // Use latest modification counter and the start date of the latest pump event that could start a scheduled basal, one
                // of scheduled basal, resume, or temp basal. Do NOT use the end date, though, because it is possible the scheduled
                // basal or temp basal recorded are still in-progress. If that is the case, then the last event will be repeated
                // (which is correct since it was still in-progress).
                if let modificationCounter = events.compactMap({ $0.modificationCounter }).max() {
                    queryAnchor.modificationCounter = modificationCounter
                }
                if let scheduledBasalStartDate = events.filter({ $0.delineatesScheduledBasal }).last?.endDate {
                    queryAnchor.scheduledBasalStartDate = scheduledBasalStartDate
                }

                completion(.success(queryAnchor, events.map { $0.syncPumpEvent }))
            }
        }
    }

    fileprivate static var storedDateFormatter: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter
    }()
}

// MARK: - Critical Event Log Export

extension DoseStore: CriticalEventLog {
    private var exportProgressUnitCountPerObject: Int64 { 1 }
    private var exportFetchLimit: Int { Int(criticalEventLogExportProgressUnitCountPerFetch / exportProgressUnitCountPerObject) }

    public var exportName: String { "Doses.json" }

    public func exportProgressTotalUnitCount(startDate: Date, endDate: Date? = nil) -> Result<Int64, Error> {
        var result: Result<Int64, Error>?

        self.persistenceController.managedObjectContext.performAndWait {
            do {
                let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
                request.predicate = self.exportDatePredicate(startDate: startDate, endDate: endDate)

                let objectCount = try self.persistenceController.managedObjectContext.count(for: request)
                result = .success(Int64(objectCount) * exportProgressUnitCountPerObject)
            } catch let error {
                result = .failure(error)
            }
        }

        return result!
    }

    public func export(startDate: Date, endDate: Date, to stream: OutputStream, progress: Progress) -> Error? {
        let encoder = JSONStreamEncoder(stream: stream)
        var modificationCounter: Int64 = 0
        var fetching = true
        var error: Error?

        while fetching && error == nil {
            self.persistenceController.managedObjectContext.performAndWait {
                do {
                    guard !progress.isCancelled else {
                        throw CriticalEventLogError.cancelled
                    }

                    let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "modificationCounter > %d", modificationCounter),
                                                                                            self.exportDatePredicate(startDate: startDate, endDate: endDate)])
                    request.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                    request.fetchLimit = self.exportFetchLimit

                    let objects = try self.persistenceController.managedObjectContext.fetch(request)
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
        var predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        if let endDate = endDate {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, NSPredicate(format: "date < %@", endDate as NSDate)])
        }
        return predicate
    }
}

// MARK: - Core Data (Bulk) - TEST ONLY

extension DoseStore {
    public func addPumpEvents(events: [PersistedPumpEvent]) -> Error? {
        guard !events.isEmpty else {
            return nil
        }

        var error: Error?

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        self.persistenceController.managedObjectContext.perform {
            for event in events {
                let object = PumpEvent(context: self.persistenceController.managedObjectContext)
                object.update(from: event)
            }
            self.persistenceController.save { saveError in
                guard saveError == nil else {
                    error = saveError
                    dispatchGroup.leave()
                    return
                }
                self.syncPumpEventsToInsulinDeliveryStore(after: events.compactMap { $0.date }.min()) { syncError in
                    error = syncError
                    dispatchGroup.leave()
                }
            }
        }
        dispatchGroup.wait()

        guard error == nil else {
            return error
        }

        self.log.info("Added %d PumpEvents", events.count)
        self.delegate?.doseStoreHasUpdatedPumpData(self)
        return nil
    }
}

fileprivate struct SyncPumpEventWithModificationCounter {
    let syncPumpEvent: SyncPumpEvent
    let modificationCounter: Int64?

    init(_ syncPumpEvent: SyncPumpEvent, modificationCounter: Int64? = nil) {
        self.syncPumpEvent = syncPumpEvent
        self.modificationCounter = modificationCounter
    }

    var startDate: Date { syncPumpEvent.dose?.startDate ?? syncPumpEvent.date }

    var endDate: Date { syncPumpEvent.dose?.endDate ?? syncPumpEvent.date }

    var delineatesScheduledBasal: Bool {
        switch syncPumpEvent.type {
        case .basal, .resume, .tempBasal:
            return !syncPumpEvent.mutable
        default:
            return false
        }
    }

    // Stable sort order even if date and type match
    static func sort(_ lhs: Self, _ rhs: Self) -> Bool {
        switch lhs.startDate.compare(rhs.startDate) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            switch lhs.syncPumpEvent.type.sortOrder.compare(rhs.syncPumpEvent.type.sortOrder) {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                return lhs.syncPumpEvent.syncIdentifier < rhs.syncPumpEvent.syncIdentifier
            }
        }
    }
}

fileprivate extension PumpEvent {
    var syncPumpEventWithModificationCounter: SyncPumpEventWithModificationCounter? {
        guard let syncPumpEvent = syncPumpEvent else {
            return nil
        }
        return SyncPumpEventWithModificationCounter(syncPumpEvent, modificationCounter: modificationCounter)
    }

    private var syncPumpEvent: SyncPumpEvent? {
        guard let type = type, let syncIdentifier = syncIdentifier else {
            return nil
        }
        return SyncPumpEvent(date: date, type: type, alarmType: alarmType, mutable: mutable, dose: dose, syncIdentifier: syncIdentifier)
    }
}

fileprivate extension DoseEntry {
    var syncPumpEventWithModificationCounter: SyncPumpEventWithModificationCounter? {
        guard let syncPumpEvent = syncPumpEvent else {
            return nil
        }
        return SyncPumpEventWithModificationCounter(syncPumpEvent)
    }

    private var syncPumpEvent: SyncPumpEvent? {
        guard let syncIdentifier = syncIdentifier else {
            return nil
        }
        return SyncPumpEvent(date: startDate, type: type.pumpEventType, mutable: false, dose: self, syncIdentifier: syncIdentifier)
    }
}
fileprivate extension Array {
    func split(at index: Int) -> (Array<Element>, Array<Element>) {
        guard index <= endIndex else {
            return (self, [])
        }
        return (Array(self[0..<index]), Array(self[index..<endIndex]))
    }
}

fileprivate extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

fileprivate extension Int {
    func compare(_ other: Int) -> ComparisonResult {
        if self < other {
            return .orderedAscending
        } else if self > other {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
}
