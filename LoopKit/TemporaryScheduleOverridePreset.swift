//
//  TemporaryScheduleOverridePreset.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


public struct TemporaryScheduleOverridePreset: Hashable {
    public var symbol: String
    public var name: String
    public var settings: TemporaryScheduleOverrideSettings
    public var duration: TemporaryScheduleOverride.Duration

    public init(symbol: String, name: String, settings: TemporaryScheduleOverrideSettings, duration: TemporaryScheduleOverride.Duration) {
        self.symbol = symbol
        self.name = name
        self.settings = settings
        self.duration = duration
    }

    public func createOverride(beginningAt date: Date = Date()) -> TemporaryScheduleOverride {
        return TemporaryScheduleOverride(
            context: .preset(self),
            settings: settings,
            startDate: date,
            duration: duration
        )
    }
}

extension TemporaryScheduleOverridePreset: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let symbol = rawValue["symbol"] as? String,
            let name = rawValue["name"] as? String,
            let settingsRawValue = rawValue["settings"] as? TemporaryScheduleOverrideSettings.RawValue,
            let settings = TemporaryScheduleOverrideSettings(rawValue: settingsRawValue),
            let durationRawValue = rawValue["duration"] as? TemporaryScheduleOverride.Duration.RawValue,
            let duration = TemporaryScheduleOverride.Duration(rawValue: durationRawValue)
        else {
            return nil
        }

        self.init(symbol: symbol, name: name, settings: settings, duration: duration)
    }

    public var rawValue: RawValue {
        return [
            "symbol": symbol,
            "name": name,
            "settings": settings.rawValue,
            "duration": duration.rawValue
        ]
    }
}
