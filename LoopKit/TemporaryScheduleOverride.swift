//
//  TemporaryScheduleOverride.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/1/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopAlgorithm

public struct TemporaryScheduleOverride: Hashable {
    public enum Context: Hashable {
        case preMeal
        case legacyWorkout
        case preset(TemporaryScheduleOverridePreset)
        case custom
    }
    
    public enum EnactTrigger: Hashable {
        case local
        case remote(String)
    }

    public enum Duration: Hashable, Comparable {
        case finite(TimeInterval)
        case indefinite

        public var timeInterval: TimeInterval {
            switch self {
            case .finite(let interval):
                return interval
            case .indefinite:
                return .infinity
            }
        }

        public var isFinite: Bool {
            return timeInterval.isFinite
        }
        
        public var isInfinite: Bool {
            return timeInterval.isInfinite
        }

        public static func < (lhs: Duration, rhs: Duration) -> Bool {
            return lhs.timeInterval < rhs.timeInterval
        }
    }

    public var context: Context
    public var settings: TemporaryScheduleOverrideSettings
    public var startDate: Date
    public let enactTrigger: EnactTrigger
    public let syncIdentifier: UUID
    
    public var actualEnd: End = .natural
    
    public var actualEndDate: Date {
        switch actualEnd {
        case .natural:
            return scheduledEndDate
        case .early(let endDate):
            return endDate
        case .deleted:
            return scheduledEndDate
        }
    }

    public var duration: Duration {
        didSet {
            precondition(duration.timeInterval > 0)
        }
    }

    public var scheduledEndDate: Date {
        get {
            return startDate + duration.timeInterval
        }
        set {
            precondition(newValue > startDate)
            if newValue == .distantFuture {
                duration = .indefinite
            } else {
                duration = .finite(newValue.timeIntervalSince(startDate))
            }
        }
    }

    public var activeInterval: DateInterval {
        return DateInterval(start: startDate, end: actualEndDate)
    }
    
    public var scheduledInterval: DateInterval {
        get {
            return DateInterval(start: startDate, end: scheduledEndDate)
        }
        set {
            startDate = newValue.start
            scheduledEndDate = newValue.end
        }
    }

    public func hasFinished(relativeTo date: Date = Date()) -> Bool {
        return date > actualEndDate
    }

    public init(
        context: Context,
        settings: TemporaryScheduleOverrideSettings,
        startDate: Date,
        duration: Duration,
        enactTrigger: EnactTrigger,
        syncIdentifier: UUID,
        actualEnd: End = .natural
    ) {
        precondition(duration.timeInterval > 0)
        self.context = context
        self.settings = settings
        self.startDate = startDate
        self.duration = duration
        self.enactTrigger = enactTrigger
        self.syncIdentifier = syncIdentifier
        self.actualEnd = actualEnd
    }
    
    public func isActive(at date: Date = Date()) -> Bool {
        return activeInterval.contains(date)
    }
}

extension TemporaryScheduleOverride: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let contextRawValue = rawValue["context"] as? Context.RawValue,
            let context = Context(rawValue: contextRawValue),
            let settingsRawValue = rawValue["settings"] as? TemporaryScheduleOverrideSettings.RawValue,
            let settings = TemporaryScheduleOverrideSettings(rawValue: settingsRawValue),
            let startDateSeconds = rawValue["startDate"] as? TimeInterval,
            let durationRawValue = rawValue["duration"] as? Duration.RawValue,
            let duration = Duration(rawValue: durationRawValue)
        else {
            return nil
        }
        
        let startDate = Date(timeIntervalSince1970: startDateSeconds)

        let enactTrigger: EnactTrigger
        if let enactTriggerRaw = rawValue["enactTrigger"] as? EnactTrigger.RawValue,
            let storedEnactTrigger = EnactTrigger(rawValue: enactTriggerRaw)
        {
            enactTrigger = storedEnactTrigger
        } else {
            enactTrigger = .local
        }

        let syncIdentifier: UUID
        if let syncIdentifierRaw = rawValue["syncIdentifier"] as? String,
            let storedSyncIdentifier = UUID(uuidString: syncIdentifierRaw) {
            syncIdentifier = storedSyncIdentifier
        } else {
            syncIdentifier = UUID()
        }
        
        self.init(context: context, settings: settings, startDate: startDate, duration: duration, enactTrigger: enactTrigger, syncIdentifier: syncIdentifier)
    }

    public var rawValue: RawValue {
        return [
            "context": context.rawValue,
            "settings": settings.rawValue,
            "startDate": startDate.timeIntervalSince1970,
            "duration": duration.rawValue,
            "syncIdentifier": syncIdentifier.uuidString,
            "enactTrigger": enactTrigger.rawValue,
        ]
    }
}

extension TemporaryScheduleOverride: Codable {}

extension TemporaryScheduleOverride.Context: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let context = rawValue["context"] as? String else {
            return nil
        }

        switch context {
        case "premeal":
            self = .preMeal
        case "legacyWorkout":
            self = .legacyWorkout
        case "preset":
            guard
                let presetRawValue = rawValue["preset"] as? TemporaryScheduleOverridePreset.RawValue,
                let preset = TemporaryScheduleOverridePreset(rawValue: presetRawValue)
            else {
                return nil
            }
            self = .preset(preset)
        case "custom":
            self = .custom
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .preMeal:
            return ["context": "premeal"]
        case .legacyWorkout:
            return ["context": "legacyWorkout"]
        case .preset(let preset):
            return [
                "context": "preset",
                "preset": preset.rawValue
            ]
        case .custom:
            return ["context": "custom"]
        }
    }
}

extension TemporaryScheduleOverride.Context: Codable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            switch string {
            case CodableKeys.preMeal.rawValue:
                self = .preMeal
            case CodableKeys.legacyWorkout.rawValue:
                self = .legacyWorkout
            case CodableKeys.custom.rawValue:
                self = .custom
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodableKeys.self)
            if let preset = try container.decodeIfPresent(Preset.self, forKey: .preset) {
                self = .preset(preset.preset)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .preMeal:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.preMeal.rawValue)
        case .legacyWorkout:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.legacyWorkout.rawValue)
        case .preset(let preset):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(Preset(preset: preset), forKey: .preset)
        case .custom:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.custom.rawValue)
        }
    }

    private struct Preset: Codable {
        let preset: TemporaryScheduleOverridePreset
    }

    private enum CodableKeys: String, CodingKey {
        case preMeal
        case legacyWorkout
        case preset
        case custom
    }
}

extension TemporaryScheduleOverride.Duration: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let duration = rawValue["duration"] as? String else {
            return nil
        }

        switch duration {
        case "finite":
            guard let interval = rawValue["interval"] as? TimeInterval else {
                return nil
            }
            self = .finite(interval)
        case "indefinite":
            self = .indefinite
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .finite(let interval):
            return [
                "duration": "finite",
                "interval": interval
            ]
        case .indefinite:
            return ["duration": "indefinite"]
        }
    }
}

extension TemporaryScheduleOverride.Duration: Codable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            switch string {
            case CodableKeys.indefinite.rawValue:
                self = .indefinite
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodableKeys.self)
            if let finite = try container.decodeIfPresent(Finite.self, forKey: .finite) {
                self = .finite(finite.duration)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .finite(let duration):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(Finite(duration: duration), forKey: .finite)
        case .indefinite:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.indefinite.rawValue)
        }
    }

    private struct Finite: Codable {
        let duration: TimeInterval
    }

    private enum CodableKeys: String, CodingKey {
        case finite
        case indefinite
    }
}

extension TemporaryScheduleOverride.EnactTrigger: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let trigger = rawValue["trigger"] as? String else {
            return nil
        }
        
        switch trigger {
        case "local":
            self = .local
        case "remote":
            guard let remoteAddress = rawValue["remoteAddress"] as? String else {
                return nil
            }
            self = .remote(remoteAddress)
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .local:
            return ["trigger": "local"]
        case .remote(let remoteAddress):
            return [
                "trigger": "remote",
                "remoteAddress": remoteAddress
            ]
        }
    }
}

extension TemporaryScheduleOverride.EnactTrigger: Codable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            switch string {
            case CodableKeys.local.rawValue:
                self = .local
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodableKeys.self)
            if let remote = try container.decodeIfPresent(Remote.self, forKey: .remote) {
                self = .remote(remote.address)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .local:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.local.rawValue)
        case .remote(let address):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(Remote(address: address), forKey: .remote)
        }
    }

    private struct Remote: Codable {
        let address: String
    }

    private enum CodableKeys: String, CodingKey {
        case local
        case remote
    }
}

extension Array where Element == TemporaryScheduleOverride {

    public func applySensitivity(over timeline: [AbsoluteScheduleValue<Double>]) -> [AbsoluteScheduleValue<Double>] {
        apply(over: timeline) { value, override in
            value / override.settings.effectiveInsulinNeedsScaleFactor
        }
    }

    public func applySensitivity(over timeline: [AbsoluteScheduleValue<HKQuantity>]) -> [AbsoluteScheduleValue<HKQuantity>] {
        apply(over: timeline) { quantity, override in
            let value = quantity.doubleValue(for: .milligramsPerDeciliter)
            return HKQuantity(
                unit: .milligramsPerDeciliter,
                doubleValue: value / override.settings.effectiveInsulinNeedsScaleFactor
            )
        }
    }

    public func applyBasal(over timeline: [AbsoluteScheduleValue<Double>]) -> [AbsoluteScheduleValue<Double>] {
        apply(over: timeline) { value, override in
            value * override.settings.effectiveInsulinNeedsScaleFactor
        }
    }

    public func applyCarbRatio(over timeline: [AbsoluteScheduleValue<Double>]) -> [AbsoluteScheduleValue<Double>] {
        apply(over: timeline) { value, override in
            value * override.settings.effectiveInsulinNeedsScaleFactor
        }
    }

    /// Takes a history of scheduled targets and applies this set of overrides to it, returning a new timeline adjusted for
    /// the current or next future override, based on date.
    ///
    /// - Parameters:
    ///   - timeline: A timeline of scheduled targets.
    ///   - date: The date indicating the current time for use in a forecast creation
    ///
    /// - returns: A new timeline with an override applied, if one is applicable.
    public func applyTarget(over timeline: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>], at date: Date) -> [AbsoluteScheduleValue<ClosedRange<HKQuantity>>] {

        guard timeline.count > 0 else {
            return []
        }

        var applicableOverride: TemporaryScheduleOverride? = nil
        let scheduleEndDate = timeline.last!.endDate

        // Look for active or future override
        for override in self {
            if override.actualEndDate > date && override.startDate < scheduleEndDate {
                // override is active or future
                applicableOverride = override
                break
            }
        }

        if let applicableOverride, let overrideTarget = applicableOverride.settings.targetRange {
            var result: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>] = []

            let overrideStart = applicableOverride.startDate

            for entry in timeline {
                if entry.startDate < overrideStart {
                    if entry.endDate > overrideStart {
                        result.append(
                            AbsoluteScheduleValue(
                                startDate: entry.startDate,
                                endDate: overrideStart,
                                value: entry.value
                            )
                        )
                    } else {
                        result.append(entry)
                    }
                }

            }

            result.append(
                AbsoluteScheduleValue(
                    startDate: applicableOverride.startDate,
                    endDate: scheduleEndDate,
                    value: overrideTarget
                )
            )
            return result
        } else {
            return timeline
        }
    }

    fileprivate func apply<T>(
        over timeline: [AbsoluteScheduleValue<T>],
        transform: (T, TemporaryScheduleOverride) -> T
    ) -> [AbsoluteScheduleValue<T>]
    {
        guard timeline.count > 0 else {
            return []
        }

        var result: [AbsoluteScheduleValue<T>] = []
        var presetIndex = 0

        for entry in timeline {
            var start = entry.startDate

            while presetIndex < self.count {
                let preset = self[presetIndex]

                // Skip presets that end before this sensitivity period
                if preset.actualEndDate < start {
                    presetIndex += 1
                    continue
                }

                if preset.isActive(at: start) {
                    let newValue = transform(entry.value, preset)
                    let end = Swift.min(entry.endDate, preset.actualEndDate)
                    result.append(AbsoluteScheduleValue(
                        startDate: start,
                        endDate: end,
                        value: newValue
                    ))
                    if entry.endDate > end {
                        presetIndex += 1
                    }

                    if preset.actualEndDate > entry.endDate {
                        break
                    }

                    start = end
                } else if preset.startDate < entry.endDate {
                    result.append(AbsoluteScheduleValue(
                        startDate: start,
                        endDate: preset.startDate,
                        value: entry.value
                    ))
                    let newValue = transform(entry.value, preset)
                    let endDate = Swift.min(entry.endDate, preset.actualEndDate)
                    result.append(AbsoluteScheduleValue(
                        startDate: preset.startDate,
                        endDate: endDate,
                        value: newValue
                    ))
                    start = endDate
                    if preset.actualEndDate > entry.endDate {
                        break
                    }
                    presetIndex += 1
                } else {
                    break
                }
            }
            if start < entry.endDate {
                result.append(AbsoluteScheduleValue(
                    startDate: start,
                    endDate: entry.endDate,
                    value: entry.value
                ))
                start = entry.endDate
            }
        }
        return result
    }
}
