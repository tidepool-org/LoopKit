//
//  PersistentDeviceLog.swift
//  LoopKit
//
//  Created by Pete Schwamb on 1/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData
import os.log


// Using a framework specific class will search the framework's bundle for model files.
class PersistentContainer: NSPersistentContainer { }

public class PersistentDeviceLog {
    
    public static let maxEntryAgeDefault = TimeInterval(7 * 24 * 60 * 60)

    private let storageFile: URL
    
    private let managedObjectContext: NSManagedObjectContext

    private let persistentContainer: NSPersistentContainer
    
    private let maxEntryAge: TimeInterval
    
    private var earliestLogEntryDate: Date {
        return Date(timeIntervalSinceNow: -maxEntryAge)
    }
    
    private let log = OSLog(category: "PersistentDeviceLog")
    
    public init(storageFile: URL, maxEntryAge: TimeInterval = PersistentDeviceLog.maxEntryAgeDefault) {
        self.storageFile = storageFile
        self.maxEntryAge = max(maxEntryAge, PersistentDeviceLog.maxEntryAgeDefault)

        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        managedObjectContext.automaticallyMergesChangesFromParent = true

        let storeDescription = NSPersistentStoreDescription(url: storageFile)
        persistentContainer = PersistentContainer(name: "DeviceLog")
        persistentContainer.persistentStoreDescriptions = [storeDescription]
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        managedObjectContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
    }
    
    public func log(managerIdentifier: String, deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)? = nil) {
        managedObjectContext.perform {
            let entry = DeviceLogEntry(context: self.managedObjectContext)
            entry.managerIdentifier = managerIdentifier
            entry.deviceIdentifier = deviceIdentifier
            entry.type = type
            entry.message = message
            entry.timestamp = Date()
            do {
                try self.managedObjectContext.save()
                self.log.default("Logged: %{public}@ (%{public}@) %{public}@", String(describing: type), deviceIdentifier ?? "", message)
                completion?(nil)
            } catch let error {
                self.log.error("Could not store device log entry %{public}@", String(describing: error))
                completion?(error)
            }
        }
    }
    
    public func getLogEntries(startDate: Date, endDate: Date? = nil, completion: @escaping (_ result: Result<[StoredDeviceLogEntry], Error>) -> Void) {
        
        managedObjectContext.perform {
            var predicate: NSPredicate = NSPredicate(format: "timestamp >= %@", startDate as NSDate)
            if let endDate = endDate {
                let endFilter = NSPredicate(format: "timestamp < %@", endDate as NSDate)
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, endFilter])
            }
            
            let request: NSFetchRequest<DeviceLogEntry> = DeviceLogEntry.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            do {
                let entries = try self.managedObjectContext.fetch(request)
                completion(.success(entries.map { StoredDeviceLogEntry(managedObject: $0) } ))
                self.purgeExpiredLogEntries()
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    // Should only be called from managed object context queue
    private func purgeExpiredLogEntries() {
        let predicate = NSPredicate(format: "timestamp < %@", earliestLogEntryDate as NSDate)

        do {
            let fetchRequest: NSFetchRequest<DeviceLogEntry> = DeviceLogEntry.fetchRequest()
            fetchRequest.predicate = predicate
            let count = try managedObjectContext.deleteObjects(matching: fetchRequest)
            log.info("Deleted %d DeviceLogEntries", count)
        } catch let error {
            log.error("Could not purge expired log entry %{public}@", String(describing: error))
        }
    }
}

// MARK: - Simulated Core Data

extension PersistentDeviceLog {
    private var historicalEndDate: Date { Date(timeIntervalSinceNow: -.hours(24)) }
    private var historicalEntriesPerDay: Int { 6000 }

    public func generateSimulatedHistoricalDeviceLogEntries(completion: @escaping (Error?) -> Void) {
        var startDate = Calendar.current.startOfDay(for: self.earliestLogEntryDate)
        let endDate = Calendar.current.startOfDay(for: self.historicalEndDate)
        var generateError: Error?
        var entryCount = 0

        self.managedObjectContext.performAndWait {
            while startDate < endDate {
                for index in 0..<self.historicalEntriesPerDay {
                    let entry = DeviceLogEntry(context: self.managedObjectContext)
                    entry.simulated(timestamp: startDate.addingTimeInterval(.hours(Double(index) * 24.0 / Double(self.historicalEntriesPerDay))))
                    entryCount += 1
                }

                // We must save each day since there are so many historical entries
                do {
                    try self.managedObjectContext.save()
                } catch let error {
                    generateError = error
                    return
                }

                startDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
            }

            self.log.info("Generated %d historical DeviceLogEntries", entryCount)
        }

        completion(generateError)
    }

    public func purgeHistoricalDeviceLogEntries(completion: @escaping (Error?) -> Void) {
        let predicate = NSPredicate(format: "timestamp < %@", self.historicalEndDate as NSDate)
        var purgeError: Error?

        do {
            let count = try self.managedObjectContext.purgeObjects(of: DeviceLogEntry.self, matching: predicate)
            self.log.info("Purged %d historical DeviceLogEntries", count)
        } catch let error {
            self.log.error("Unable to purge historical DeviceLogEntries: %@", String(describing: error))
            purgeError = error
        }

        completion(purgeError)
    }
}

fileprivate extension DeviceLogEntry {
    func simulated(timestamp: Date) {
        self.timestamp = timestamp
        self.type = .connection
        self.managerIdentifier = "SimulatedMId"
        self.deviceIdentifier = "SimulatedDId"
        self.message = "This is an simulated message for the PersistentDeviceLog. In an analysis performed on June 1, 2020, the current average length of these messages is about 225 characters. This string should also be approximately that length."
    }
}
