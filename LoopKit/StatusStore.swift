//
//  StatusStore.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public class StatusStore {

    private let dataAccessQueue = DispatchQueue(label: "com.loopkit.StatusStore.DataAccessQueue", qos: .utility)

    private let userDefaults: UserDefaults?

    private var statuses: [Int64: StoredStatus]

    private var modificationCounter: Int64 {
        didSet {
            userDefaults?.statusStoreModificationCounter = modificationCounter
        }
    }

    public init(userDefaults: UserDefaults?) {
        self.userDefaults = userDefaults
        self.statuses = [:]
        self.modificationCounter = userDefaults?.statusStoreModificationCounter ?? 0
    }

    public func addStatus(_ status: StoredStatus) {
        dataAccessQueue.async {
            self.modificationCounter += 1
            self.statuses[self.modificationCounter] = status
        }
    }

}

extension StatusStore: StatusRemoteDataQueryDelegate {

    public func queryStatusRemoteData(anchor: DatedQueryAnchor<StatusQueryAnchor>, limit: Int, completion: @escaping (Result<StatusQueryAnchoredRemoteData, Error>) -> Void) {
        dataAccessQueue.async {
            var result = StatusQueryAnchoredRemoteData(anchor: anchor, data: StatusRemoteData())

            let anchorModificationCounter = (anchor.anchor.modificationCounter ?? 0) + 1
            if anchorModificationCounter <= self.modificationCounter {
                for modificationCounter in (anchorModificationCounter...self.modificationCounter) {
                    if let status = self.statuses[modificationCounter] {
                        result.data.append(status)
                    }
                }

                result.anchor.anchor.modificationCounter = self.modificationCounter
            }

            completion(.success(result))
        }
    }

}

public struct StoredStatus {

    public let date: Date = Date()

    public var insulinOnBoard: InsulinValue?

    public var carbsOnBoard: CarbValue?

    public var predictedGlucose: [PredictedGlucoseValue]?

    public var tempBasalRecommendationDate: TempBasalRecommendationDate?

    public var recommendedBolus: Double?

    public var lastReservoirValue: LastReservoirValue?

    public var pumpManagerStatus: PumpManagerStatus?

    public var glucoseTargetRangeSchedule: GlucoseRangeSchedule?

    public var scheduleOverride: TemporaryScheduleOverride?

    public var glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule?

    public var error: Error?

    public init() {}

}

public struct TempBasalRecommendationDate {

    public let recommendation: TempBasalRecommendation

    public let date: Date

    public init(recommendation: TempBasalRecommendation, date: Date) {
        self.recommendation = recommendation
        self.date = date
    }

}

public struct LastReservoirValue {

    public let startDate: Date

    public let unitVolume: Double

    public init(startDate: Date, unitVolume: Double) {
        self.startDate = startDate
        self.unitVolume = unitVolume
    }

}

fileprivate extension UserDefaults {

    private enum Key: String {
        case statusStoreModificationCounter = "com.loopkit.StatusStore.ModificationCounter"
    }

    var statusStoreModificationCounter: Int64? {
        get {
            guard let value = object(forKey: Key.statusStoreModificationCounter.rawValue) as? NSNumber else {
                return nil
            }
            return value.int64Value
        }
        set {
            if let newValue = newValue {
                set(NSNumber(value: newValue), forKey: Key.statusStoreModificationCounter.rawValue)
            } else {
                removeObject(forKey: Key.statusStoreModificationCounter.rawValue)
            }
        }
    }

}
