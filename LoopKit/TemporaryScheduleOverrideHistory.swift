//
//  TemporaryScheduleOverrideHistory.swift
//  LoopKit
//
//  Created by Michael Pangburn on 3/25/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


private struct OverrideEvent: Equatable {
    enum End: Equatable {
        case natural
        case early(Date)
    }

    var override: TemporaryScheduleOverride
    var end: End = .natural

    init(override: TemporaryScheduleOverride) {
        self.override = override
    }

    var actualEndDate: Date {
        switch end {
        case .natural:
            return override.endDate
        case .early(let endDate):
            return endDate
        }
    }
}


public protocol TemporaryScheduleOverrideHistoryDelegate: AnyObject {
    func temporaryScheduleOverrideHistoryDidUpdate(_ history: TemporaryScheduleOverrideHistory)
}

public final class TemporaryScheduleOverrideHistory {
    private var recentEvents: [OverrideEvent] = [] {
        didSet {
            delegate?.temporaryScheduleOverrideHistoryDidUpdate(self)
        }
    }

    public weak var delegate: TemporaryScheduleOverrideHistoryDelegate?

    public init() {}

    public func recordOverride(_ override: TemporaryScheduleOverride?, at enableDate: Date = Date()) {
        guard override != recentEvents.last?.override else {
            return
        }

        if  let lastEvent = recentEvents.last,
            case .natural = lastEvent.end,
            !lastEvent.override.hasFinished(relativeTo: enableDate)
        {
            let activeOverrideHasNotBegun = lastEvent.override.startDate > enableDate
            let activeOverrideEdited = override?.startDate == lastEvent.override.startDate
            if activeOverrideHasNotBegun || activeOverrideEdited {
                recentEvents.removeLast()
            } else {
                // If a new override was enabled, ensure the active intervals do not overlap.
                let overrideEnd: Date
                if let override = override {
                    overrideEnd = min(override.startDate.nearestPrevious, enableDate)
                } else {
                    overrideEnd = enableDate
                }
                recentEvents[recentEvents.endIndex - 1].end = .early(overrideEnd)
            }
        }

        if let override = override {
            let enabledEvent = OverrideEvent(override: override)
            recentEvents.append(enabledEvent)
        }
    }

    public func resolvingRecentBasalSchedule(_ base: BasalRateSchedule, relativeTo referenceDate: Date = Date()) -> BasalRateSchedule {
        filterRecentEvents(relativeTo: referenceDate)
        return overridesReflectingEnabledDuration.reduce(base) { base, override in
            base.applyingBasalRateMultiplier(from: override, relativeTo: referenceDate)
        }
    }

    public func resolvingRecentInsulinSensitivitySchedule(_ base: InsulinSensitivitySchedule, relativeTo referenceDate: Date = Date()) -> InsulinSensitivitySchedule {
        filterRecentEvents(relativeTo: referenceDate)
        return overridesReflectingEnabledDuration.reduce(base) { base, override in
            base.applyingSensitivityMultiplier(from: override, relativeTo: referenceDate)
        }
    }

    public func resolvingRecentCarbRatioSchedule(_ base: CarbRatioSchedule, relativeTo referenceDate: Date = Date()) -> CarbRatioSchedule {
        filterRecentEvents(relativeTo: referenceDate)
        return overridesReflectingEnabledDuration.reduce(base) { base, override in
            base.applyingCarbRatioMultiplier(from: override, relativeTo: referenceDate)
        }
    }

    private func filterRecentEvents(relativeTo referenceDate: Date) {
        let oldestEndDateToKeep = referenceDate.addingTimeInterval(-CarbStore.defaultMaximumAbsorptionTimeInterval)

        var recentEvents = self.recentEvents
        recentEvents.removeAll(where: { event in
            event.actualEndDate < oldestEndDateToKeep
        })

        if recentEvents != self.recentEvents {
            self.recentEvents = recentEvents
        }
    }

    private var overridesReflectingEnabledDuration: [TemporaryScheduleOverride] {
        let overrides = recentEvents.map { event -> TemporaryScheduleOverride in
            var override = event.override
            if case .early(let endDate) = event.end {
                override.endDate = endDate
            }
            return override
        }

        precondition(overrides.adjacentPairs().allSatisfy { override, next in
            !override.activeInterval.intersects(next.activeInterval)
        }, "No overrides should overlap.")

        return overrides
    }

    func wipeHistory() {
        recentEvents.removeAll()
    }
}


extension OverrideEvent: RawRepresentable {
    typealias RawValue = [String: Any]

    init?(rawValue: RawValue) {
        guard
            let overrideRawValue = rawValue["override"] as? TemporaryScheduleOverride.RawValue,
            let override = TemporaryScheduleOverride(rawValue: overrideRawValue)
        else {
            return nil
        }

        self.override = override

        if let endDate = rawValue["endDate"] as? Date {
            self.end = .early(endDate)
        }
    }

    var rawValue: RawValue {
        var raw: RawValue = [
            "override": override.rawValue
        ]

        if case .early(let endDate) = end {
            raw["endDate"] = endDate
        }

        return raw
    }
}


extension TemporaryScheduleOverrideHistory: RawRepresentable {
    public typealias RawValue = [[String: Any]]

    public convenience init?(rawValue: RawValue) {
        self.init()
        self.recentEvents = rawValue.compactMap(OverrideEvent.init(rawValue:))
    }

    public var rawValue: RawValue {
        return recentEvents.map { $0.rawValue }
    }
}


extension TemporaryScheduleOverrideHistory: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "TemporaryScheduleOverrideHistory(recentEvents: \(recentEvents))"
    }
}


private extension Date {
    var nearestPrevious: Date {
        return Date(timeIntervalSince1970: timeIntervalSince1970.nextDown)
    }
}
