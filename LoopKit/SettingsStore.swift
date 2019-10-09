//
//  SettingsStore.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public class SettingsStore {

    private let dataAccessQueue = DispatchQueue(label: "com.loopkit.SettingsStore.DataAccessQueue", qos: .utility)

    private let userDefaults: UserDefaults?

    private var settings: [Int64: StoredSettings]

    private var modificationCounter: Int64 {
        didSet {
            userDefaults?.settingsStoreModificationCounter = modificationCounter
        }
    }

    public init(userDefaults: UserDefaults?) {
        self.userDefaults = userDefaults
        self.settings = [:]
        self.modificationCounter = userDefaults?.settingsStoreModificationCounter ?? 0
    }

    public func addSettings(_ settings: StoredSettings) {
        dataAccessQueue.async {
            self.modificationCounter += 1
            self.settings[self.modificationCounter] = settings
        }
    }

}

extension SettingsStore: SettingsRemoteDataQueryDelegate {

    public func querySettingsRemoteData(anchor: DatedQueryAnchor<SettingsQueryAnchor>, limit: Int, completion: @escaping (Result<SettingsQueryAnchoredRemoteData, Error>) -> Void) {
        dataAccessQueue.async {
            var result = SettingsQueryAnchoredRemoteData(anchor: anchor, data: SettingsRemoteData())
            
            let anchorModificationCounter = (anchor.anchor.modificationCounter ?? 0) + 1
            if anchorModificationCounter <= self.modificationCounter {
                for modificationCounter in (anchorModificationCounter...self.modificationCounter) {
                    if let settings = self.settings[modificationCounter] {
                        result.data.append(settings)
                    }
                }

                result.anchor.anchor.modificationCounter = self.modificationCounter
            }

            completion(.success(result))
        }
    }

}

public struct StoredSettings {

    public var date: Date = Date()

    public var dosingEnabled: Bool = false

    public var glucoseTargetRangeSchedule: GlucoseRangeSchedule?

    public var preMealTargetRange: DoubleRange?

    public var overridePresets: [TemporaryScheduleOverridePreset] = []

    public var scheduleOverride: TemporaryScheduleOverride?

    public var maximumBasalRatePerHour: Double?

    public var maximumBolus: Double?

    public var suspendThreshold: GlucoseThreshold?

    public var glucoseUnit: HKUnit?

    public var insulinModel: InsulinModel?

    public var basalRateSchedule: BasalRateSchedule?

    public var insulinSensitivitySchedule: InsulinSensitivitySchedule?

    public var carbRatioSchedule: CarbRatioSchedule?

    public init() {}

}

fileprivate extension UserDefaults {

    private enum Key: String {
        case settingsStoreModificationCounter = "com.loopkit.SettingsStore.ModificationCounter"
    }

    var settingsStoreModificationCounter: Int64? {
        get {
            guard let value = object(forKey: Key.settingsStoreModificationCounter.rawValue) as? NSNumber else {
                return nil
            }
            return value.int64Value
        }
        set {
            if let newValue = newValue {
                set(NSNumber(value: newValue), forKey: Key.settingsStoreModificationCounter.rawValue)
            } else {
                removeObject(forKey: Key.settingsStoreModificationCounter.rawValue)
            }
        }
    }

}
