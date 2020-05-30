//
//  DosingDecisionStore.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import Foundation
import CoreData
import HealthKit
import UserNotifications

public protocol DosingDecisionStoreDelegate: AnyObject {
    /**
     Informs the delegate that the dosing decision store has updated dosing decision data.
     
     - Parameter dosingDecisionStore: The dosing decision store that has updated dosing decision data.
     */
    func dosingDecisionStoreHasUpdatedDosingDecisionData(_ dosingDecisionStore: DosingDecisionStore)
}

public class DosingDecisionStore {
    public weak var delegate: DosingDecisionStoreDelegate?
    
    private let store: PersistenceController
    private let expireAfter: TimeInterval
    private let dataAccessQueue = DispatchQueue(label: "com.loopkit.DosingDecisionStore.dataAccessQueue", qos: .utility)
    public let log = OSLog(category: "DosingDecisionStore")

    public init(store: PersistenceController, expireAfter: TimeInterval) {
        self.store = store
        self.expireAfter = expireAfter
    }

    public func storeDosingDecisionData(_ dosingDecisionData: StoredDosingDecisionData, completion: @escaping () -> Void) {
        dataAccessQueue.async {
            self.store.managedObjectContext.performAndWait {
                let object = DosingDecisionObject(context: self.store.managedObjectContext)
                object.date = dosingDecisionData.date
                object.data = dosingDecisionData.data
                self.store.save()
            }

            self.purgeExpiredDosingDecisionObjects()
            completion()
        }
    }

    private var expireDate: Date {
        return Date(timeIntervalSinceNow: -expireAfter)
    }

    private func purgeExpiredDosingDecisionObjects() {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        do {
            let predicate = NSPredicate(format: "date < %@", expireDate as NSDate)
            let count = try self.store.managedObjectContext.purgeObjects(of: DosingDecisionObject.self, matching: predicate)
            self.log.info("Purged %d DosingDecisionObjects", count)
        } catch let error {
            self.log.error("Unable to purge DosingDecisionObjects: %@", String(describing: error))
        }

        self.delegate?.dosingDecisionStoreHasUpdatedDosingDecisionData(self)
    }
}

extension DosingDecisionStore {
    public struct QueryAnchor: RawRepresentable {
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
    
    public enum DosingDecisionDataQueryResult {
        case success(QueryAnchor, [StoredDosingDecisionData])
        case failure(Error)
    }
    
    public func executeDosingDecisionDataQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (DosingDecisionDataQueryResult) -> Void) {
        dataAccessQueue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryResult = [StoredDosingDecisionData]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, queryResult))
                return
            }

            self.store.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<DosingDecisionObject> = DosingDecisionObject.fetchRequest()

                storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                storedRequest.fetchLimit = limit

                do {
                    let stored = try self.store.managedObjectContext.fetch(storedRequest)
                    if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.modificationCounter = modificationCounter
                    }
                    queryResult.append(contentsOf: stored.compactMap { StoredDosingDecisionData(date: $0.date, data: $0.data) })
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

public struct StoredDosingDecisionData {
    public let date: Date
    public let data: Data

    public init(date: Date, data: Data) {
        self.date = date
        self.data = data
    }
}

public struct StoredDosingDecision {
    public let date: Date
    public let insulinOnBoard: InsulinValue?
    public let carbsOnBoard: CarbValue?
    public let scheduleOverride: TemporaryScheduleOverride?
    public let glucoseTargetRangeSchedule: GlucoseRangeSchedule?
    public let glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule?
    public let predictedGlucose: [PredictedGlucoseValue]?
    public let predictedGlucoseIncludingPendingInsulin: [PredictedGlucoseValue]?
    public let lastReservoirValue: LastReservoirValue?
    public let recommendedTempBasal: TempBasalRecommendationWithDate?
    public let recommendedBolus: BolusRecommendationWithDate?
    public let pumpManagerStatus: PumpManagerStatus?
    public let notificationSettings: UNNotificationSettings?
    public let deviceSettings: DeviceSettings?
    public let errors: [Error]?
    public let syncIdentifier: String

    public init(date: Date = Date(),
                insulinOnBoard: InsulinValue? = nil,
                carbsOnBoard: CarbValue? = nil,
                scheduleOverride: TemporaryScheduleOverride? = nil,
                glucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
                glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule? = nil,
                predictedGlucose: [PredictedGlucoseValue]? = nil,
                predictedGlucoseIncludingPendingInsulin: [PredictedGlucoseValue]? = nil,
                lastReservoirValue: LastReservoirValue? = nil,
                recommendedTempBasal: TempBasalRecommendationWithDate? = nil,
                recommendedBolus: BolusRecommendationWithDate? = nil,
                pumpManagerStatus: PumpManagerStatus? = nil,
                notificationSettings: UNNotificationSettings? = nil,
                deviceSettings: DeviceSettings? = nil,
                errors: [Error]? = nil,
                syncIdentifier: String = UUID().uuidString) {
        self.date = date
        self.insulinOnBoard = insulinOnBoard
        self.carbsOnBoard = carbsOnBoard
        self.scheduleOverride = scheduleOverride
        self.glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        self.glucoseTargetRangeScheduleApplyingOverrideIfActive = glucoseTargetRangeScheduleApplyingOverrideIfActive
        self.predictedGlucose = predictedGlucose
        self.predictedGlucoseIncludingPendingInsulin = predictedGlucoseIncludingPendingInsulin
        self.lastReservoirValue = lastReservoirValue
        self.recommendedTempBasal = recommendedTempBasal
        self.recommendedBolus = recommendedBolus
        self.pumpManagerStatus = pumpManagerStatus
        self.notificationSettings = notificationSettings
        self.deviceSettings = deviceSettings
        self.errors = errors
        self.syncIdentifier = syncIdentifier
    }

    public struct LastReservoirValue: Codable {
        public let startDate: Date
        public let unitVolume: Double

        public init(startDate: Date, unitVolume: Double) {
            self.startDate = startDate
            self.unitVolume = unitVolume
        }
    }

    public struct TempBasalRecommendationWithDate: Codable {
        public let recommendation: TempBasalRecommendation
        public let date: Date

        public init(recommendation: TempBasalRecommendation, date: Date) {
            self.recommendation = recommendation
            self.date = date
        }
    }

    public struct BolusRecommendationWithDate: Codable {
        public let recommendation: BolusRecommendation
        public let date: Date

        public init(recommendation: BolusRecommendation, date: Date) {
            self.recommendation = recommendation
            self.date = date
        }
    }

    public struct DeviceSettings: Codable, Equatable {
        let name: String
        let systemName: String
        let systemVersion: String
        let model: String
        let modelIdentifier: String
        let batteryLevel: Float?
        let batteryState: BatteryState?

        public init(name: String, systemName: String, systemVersion: String, model: String, modelIdentifier: String, batteryLevel: Float? = nil, batteryState: BatteryState? = nil) {
            self.name = name
            self.systemName = systemName
            self.systemVersion = systemVersion
            self.model = model
            self.modelIdentifier = modelIdentifier
            self.batteryLevel = batteryLevel
            self.batteryState = batteryState
        }

        public enum BatteryState: String, Codable {
            case unknown
            case unplugged
            case charging
            case full
        }
    }
}

// MARK: - Simulated Core Data

extension DosingDecisionStore {
    private var historicalEndDate: Date { Date(timeIntervalSinceNow: -.hours(24)) }
    private var historicalDosingDecisionsPerDay: Int { 288 }

    public func generateSimulatedHistoricalDosingDecisionObjects(encoder: @escaping (StoredDosingDecision) -> Data?, completion: @escaping (Error?) -> Void) {
        dataAccessQueue.async {
            var startDate = Calendar.current.startOfDay(for: self.expireDate)
            let endDate = Calendar.current.startOfDay(for: self.historicalEndDate)
            var generateError: Error?
            var dosingDecisionCount = 0

            self.store.managedObjectContext.performAndWait {
                while startDate < endDate {
                    for index in 0..<self.historicalDosingDecisionsPerDay {
                        let dosingDecision = DosingDecisionObject(context: self.store.managedObjectContext)
                        dosingDecision.date = startDate.addingTimeInterval(.hours(Double(index) * 24.0 / Double(self.historicalDosingDecisionsPerDay)))
                        dosingDecision.data = encoder(StoredDosingDecision.simulated(date: dosingDecision.date))!
                        dosingDecisionCount += 1
                    }

                    startDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
                }

                self.store.save { error in
                    guard error == nil else {
                        generateError = error
                        return
                    }

                    self.log.info("Generated %d historical DosingDecisionObjects", dosingDecisionCount)
                }
            }

            self.delegate?.dosingDecisionStoreHasUpdatedDosingDecisionData(self)
            completion(generateError)
        }
    }

    public func purgeHistoricalDosingDecisionObjects(completion: @escaping (Error?) -> Void) {
        dataAccessQueue.async {
            let predicate = NSPredicate(format: "date < %@", self.historicalEndDate as NSDate)
            var purgeError: Error?

            do {
                let count = try self.store.managedObjectContext.purgeObjects(of: DosingDecisionObject.self, matching: predicate)
                self.log.info("Purged %d historical DosingDecisionObjects", count)
            } catch let error {
                self.log.error("Unable to purge historical DosingDecisionObjects: %@", String(describing: error))
                purgeError = error
            }

            self.delegate?.dosingDecisionStoreHasUpdatedDosingDecisionData(self)
            completion(purgeError)
        }
    }
}

fileprivate extension StoredDosingDecision {
    static func simulated(date: Date) -> StoredDosingDecision {
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let insulinOnBoard = InsulinValue(startDate: date, value: 1.5)
        let carbsOnBoard = CarbValue(startDate: date,
                                     endDate: date.addingTimeInterval(.minutes(5)),
                                     quantity: HKQuantity(unit: .gram(), doubleValue: 45.5))
        let scheduleOverride = TemporaryScheduleOverride(context: .custom,
                                                         settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                     targetRange: DoubleRange(minValue: 110.0,
                                                                                                                              maxValue: 120.0),
                                                                                                     insulinNeedsScaleFactor: 1.5),
                                                         startDate: date.addingTimeInterval(-.hours(1)),
                                                         duration: .finite(.hours(3)),
                                                         enactTrigger: .local,
                                                         syncIdentifier: UUID())
        let glucoseTargetRangeSchedule = GlucoseRangeSchedule(rangeSchedule: DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                                                                   dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                                                                                                                RepeatingScheduleValue(startTime: .hours(7), value: DoubleRange(minValue: 90.0, maxValue: 100.0)),
                                                                                                                RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 110.0, maxValue: 120.0))],
                                                                                                   timeZone: timeZone)!)
        let glucoseTargetRangeScheduleApplyingOverrideIfActive = GlucoseRangeSchedule(rangeSchedule: DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                                                                                           dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                                                                                                                                        RepeatingScheduleValue(startTime: .hours(7), value: DoubleRange(minValue: 90.0, maxValue: 100.0)),
                                                                                                                                        RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 110.0, maxValue: 120.0))],
                                                                                                                           timeZone: timeZone)!)
        let predictedGlucose = [PredictedGlucoseValue(startDate: date.addingTimeInterval(.minutes(5)),
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.3)),
                                PredictedGlucoseValue(startDate: date.addingTimeInterval(.minutes(10)),
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 125.5)),
                                PredictedGlucoseValue(startDate: date.addingTimeInterval(.minutes(15)),
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 127.8))]
        let predictedGlucoseIncludingPendingInsulin = [PredictedGlucoseValue(startDate: date.addingTimeInterval(.minutes(5)),
                                                                             quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 113.3)),
                                                       PredictedGlucoseValue(startDate: date.addingTimeInterval(.minutes(10)),
                                                                             quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 115.5)),
                                                       PredictedGlucoseValue(startDate: date.addingTimeInterval(.minutes(15)),
                                                                             quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 117.8))]
        let lastReservoirValue = StoredDosingDecision.LastReservoirValue(startDate: date.addingTimeInterval(-.minutes(1)),
                                                                         unitVolume: 113.3)
        let recommendedTempBasal = StoredDosingDecision.TempBasalRecommendationWithDate(recommendation: TempBasalRecommendation(unitsPerHour: 0.75,
                                                                                                                                duration: .minutes(30)),
                                                                                        date: date.addingTimeInterval(-.minutes(1)))
        let recommendedBolus = StoredDosingDecision.BolusRecommendationWithDate(recommendation: BolusRecommendation(amount: 0.2,
                                                                                                                    pendingInsulin: 0.75,
                                                                                                                    notice: .predictedGlucoseBelowTarget(minGlucose: PredictedGlucoseValue(startDate: date.addingTimeInterval(.minutes(30)),
                                                                                                                                                                                           quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 95.0)))),
                                                                                date: date.addingTimeInterval(-.minutes(1)))
        let pumpManagerStatus = PumpManagerStatus(timeZone: timeZone,
                                                  device: HKDevice(name: "Device Name",
                                                                   manufacturer: "Device Manufacturer",
                                                                   model: "Device Model",
                                                                   hardwareVersion: "Device Hardware Version",
                                                                   firmwareVersion: "Device Firmware Version",
                                                                   softwareVersion: "Device Software Version",
                                                                   localIdentifier: "Device Local Identifier",
                                                                   udiDeviceIdentifier: "Device UDI Device Identifier"),
                                                  pumpBatteryChargeRemaining: 3.5,
                                                  basalDeliveryState: .initiatingTempBasal,
                                                  bolusState: .none)
        let deviceSettings = StoredDosingDecision.DeviceSettings(name: "Device Name",
                                                                 systemName: "Device System Name",
                                                                 systemVersion: "Device System Version",
                                                                 model: "Device Model",
                                                                 modelIdentifier: "Device Model Identifier",
                                                                 batteryLevel: 0.5,
                                                                 batteryState: .charging)

        return StoredDosingDecision(date: date,
                                    insulinOnBoard: insulinOnBoard,
                                    carbsOnBoard: carbsOnBoard,
                                    scheduleOverride: scheduleOverride,
                                    glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
                                    glucoseTargetRangeScheduleApplyingOverrideIfActive: glucoseTargetRangeScheduleApplyingOverrideIfActive,
                                    predictedGlucose: predictedGlucose,
                                    predictedGlucoseIncludingPendingInsulin: predictedGlucoseIncludingPendingInsulin,
                                    lastReservoirValue: lastReservoirValue,
                                    recommendedTempBasal: recommendedTempBasal,
                                    recommendedBolus: recommendedBolus,
                                    pumpManagerStatus: pumpManagerStatus,
                                    notificationSettings: historicalNotificationSettings,
                                    deviceSettings: deviceSettings,
                                    errors: nil,
                                    syncIdentifier: UUID().uuidString)
    }
}

fileprivate let historicalNotificationSettingsBase64 = "YnBsaXN0MDDUAQIDBAUGBwpYJHZlcnNpb25ZJGFyY2hpdmVyVCR0b3BYJG9iamVjdHMSAAGGoF8QD05TS2V" +
    "5ZWRBcmNoaXZlctEICVRyb290gAGjCwwgVSRudWxs3g0ODxAREhMUFRYXGBkaGxsbGxscHBwdHhsfHBtcYmFkZ2VTZXR0aW5nXxATYXV0aG9yaXphdGlvblN0YXR" +
    "1c1xzb3VuZFNldHRpbmdfEBlub3RpZmljYXRpb25DZW50ZXJTZXR0aW5nXxAUY3JpdGljYWxBbGVydFNldHRpbmdfEBNzaG93UHJldmlld3NTZXR0aW5nXxAPZ3J" +
    "vdXBpbmdTZXR0aW5nXmNhclBsYXlTZXR0aW5nXxAfcHJvdmlkZXNBcHBOb3RpZmljYXRpb25TZXR0aW5nc1YkY2xhc3NfEBFsb2NrU2NyZWVuU2V0dGluZ1phbGV" +
    "ydFN0eWxlXxATYW5ub3VuY2VtZW50U2V0dGluZ1xhbGVydFNldHRpbmcQAhAACIACEAHSISIjJFokY2xhc3NuYW1lWCRjbGFzc2VzXxAWVU5Ob3RpZmljYXRpb25" +
    "TZXR0aW5nc6IlJl8QFlVOTm90aWZpY2F0aW9uU2V0dGluZ3NYTlNPYmplY3QACAARABoAJAApADIANwBJAEwAUQBTAFcAXQB6AIcAnQCqAMYA3QDzAQUBFAE2AT0" +
"BUQFcAXIBfwGBAYMBhAGGAYgBjQGYAaEBugG9AdYAAAAAAAACAQAAAAAAAAAnAAAAAAAAAAAAAAAAAAAB3w=="
fileprivate let historicalNotificationSettingsData = Data(base64Encoded: historicalNotificationSettingsBase64)!
fileprivate let historicalNotificationSettings = try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(historicalNotificationSettingsData) as! UNNotificationSettings
