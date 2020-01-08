//
//  SettingsStore.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public protocol SettingsStoreDelegate: AnyObject {
    
    /**
     Informs the delegate that the settings store has updated settings data.
     
     - Parameter settingsStore: The settings store that has updated settings data.
     */
    func settingsStoreHasUpdatedSettingsData(_ settingsStore: SettingsStore)
    
}

public class SettingsStore {
    
    public weak var delegate: SettingsStoreDelegate?
    
    private let lock = UnfairLock()
    
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
    
    public func storeSettings(_ settings: StoredSettings, completion: @escaping () -> Void) {
        lock.withLock {
            self.modificationCounter += 1
            self.settings[self.modificationCounter] = settings
        }
        self.delegate?.settingsStoreHasUpdatedSettingsData(self)
        completion()
    }
    
}

extension SettingsStore {
    
    public struct QueryAnchor: RawRepresentable {
        
        public typealias RawValue = [String: Any]
        
        public var modificationCounter: Int64
        
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
    
    public enum SettingsQueryResult {
        case success(QueryAnchor, [StoredSettings])
        case failure(Error)
    }
    
    public func executeSettingsQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (SettingsQueryResult) -> Void) {
        var queryAnchor = queryAnchor ?? QueryAnchor()
        var queryResult = [StoredSettings]()
        
        lock.withLock {
            if queryAnchor.modificationCounter < self.modificationCounter && limit > 0 {
                let startModificationCounter = queryAnchor.modificationCounter + 1
                var endModificationCounter = self.modificationCounter
                if limit <= endModificationCounter - startModificationCounter {
                    endModificationCounter = queryAnchor.modificationCounter + Int64(limit)
                }
                for modificationCounter in (startModificationCounter...endModificationCounter) {
                    if let settings = self.settings[modificationCounter] {
                        queryResult.append(settings)
                    }
                }
                
                queryAnchor.modificationCounter = self.modificationCounter
            }
        }
        
        completion(.success(queryAnchor, queryResult))
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
