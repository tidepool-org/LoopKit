//
//  InsulinMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/30/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopAlgorithm

extension DoseEntry {

    public func trimmed(from start: Date? = nil, to end: Date? = nil, syncIdentifier: String? = nil) -> DoseEntry {

        let originalDuration = endDate.timeIntervalSince(startDate)

        let startDate = max(start ?? .distantPast, self.startDate)
        let endDate = max(startDate, min(end ?? .distantFuture, self.endDate))

        var trimmedDeliveredUnits: Double? = deliveredUnits
        var trimmedValue: Double = value

        if originalDuration > .ulpOfOne && (startDate > self.startDate || endDate < self.endDate) {
            let updatedActualDelivery = unitsInDeliverableIncrements * (endDate.timeIntervalSince(startDate) / originalDuration)
            if deliveredUnits != nil {
                trimmedDeliveredUnits = updatedActualDelivery
            }
            if case .units = unit  {
                trimmedValue = updatedActualDelivery
            }
        }

        return DoseEntry(
            type: type,
            startDate: startDate,
            endDate: endDate,
            value: trimmedValue,
            unit: unit,
            deliveredUnits: trimmedDeliveredUnits,
            description: description,
            syncIdentifier: syncIdentifier,
            scheduledBasalRate: scheduledBasalRate,
            insulinType: insulinType,
            automatic: automatic,
            isMutable: isMutable,
            wasProgrammedByPumpUI: wasProgrammedByPumpUI
        )
    }
}
//
//
/**
 It takes a MM x22 pump about 40s to deliver 1 Unit while bolusing
 See: http://www.healthline.com/diabetesmine/ask-dmine-speed-insulin-pumps#3

 The x23 and newer pumps can deliver at 2x, 3x, and 4x that speed, targeting
 a maximum 5-minute delivery for all boluses (8U - 25U)

 A basal rate of 30 U/hour (near-max) would deliver an additional 0.5 U/min.
 */
fileprivate let MaximumReservoirDropPerMinute = 6.5


extension Collection where Element: ReservoirValue {
    /**
     Converts a continuous, chronological sequence of reservoir values to a sequence of doses

     This is an O(n) operation.

     - returns: An array of doses
     */
    var doseEntries: [DoseEntry] {
        var doses: [DoseEntry] = []
        var previousValue: Element?

        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 3

        for value in self {
            if let previousValue = previousValue {
                let volumeDrop = previousValue.unitVolume - value.unitVolume
                let duration = value.startDate.timeIntervalSince(previousValue.startDate)

                if duration > 0 && 0 <= volumeDrop && volumeDrop <= MaximumReservoirDropPerMinute * duration.minutes {
                    doses.append(DoseEntry(
                        type: .tempBasal,
                        startDate: previousValue.startDate,
                        endDate: value.startDate,
                        value: volumeDrop,
                        unit: .units,
                        deliveredUnits: volumeDrop
                    ))
                }
            }

            previousValue = value
        }

        return doses
    }
//
    /**
     Whether a span of chronological reservoir values is considered continuous and therefore reliable.

     Reservoir values of 0 are automatically considered unreliable due to the assumption that an unknown amount of insulin can be delivered after the 0 marker.

     - parameter startDate:       The beginning of the interval in which to validate continuity
     - parameter endDate:         The end of the interval in which to validate continuity
     - parameter maximumDuration: The maximum interval to consider reliable for a reservoir-derived dose

     - returns: Whether the reservoir values meet the critera for continuity
     */
    func isContinuous(from start: Date?, to end: Date, within maximumDuration: TimeInterval) -> Bool {
        guard let firstValue = self.first else {
            return false
        }

        // The first value has to be at least as old as the start date, as a reference point.
        let startDate = start ?? firstValue.endDate
        guard firstValue.endDate <= startDate else {
            return false
        }

        var lastValue = firstValue

        for value in self {
            defer {
                lastValue = value
            }

            // Volume and interval validation only applies for values in the specified range,
            guard value.endDate >= startDate && value.startDate <= end else {
                continue
            }

            // We can't trust 0. What else was delivered?
            guard value.unitVolume > 0 else {
                return false
            }

            // Rises in reservoir volume indicate a rewind + prime, and primes
            // can be easily confused with boluses.
            // Small rises (1 U) can be ignored as they're indicative of a mixed-precision sequence.
            guard value.unitVolume <= lastValue.unitVolume + 1 else {
                return false
            }

            // Ensure no more than the maximum interval has passed
            guard value.startDate.timeIntervalSince(lastValue.endDate) <= maximumDuration else {
                return false
            }
        }

        return true
    }
}

extension DoseEntry {
    fileprivate var resolvingDelivery: DoseEntry {
        guard !isMutable, deliveredUnits == nil else {
            return self
        }

        let resolvedUnits: Double

        if case .units = unit {
            resolvedUnits = value
        } else {
            switch type {
            case .tempBasal:
                resolvedUnits = unitsInDeliverableIncrements
            case .basal:
                resolvedUnits = programmedUnits
            default:
                return self
            }
        }
        return DoseEntry(type: type, startDate: startDate, endDate: endDate, value: value, unit: unit, deliveredUnits: resolvedUnits, description: description, syncIdentifier: syncIdentifier, scheduledBasalRate: scheduledBasalRate, insulinType: insulinType, automatic: automatic, isMutable: isMutable, wasProgrammedByPumpUI: wasProgrammedByPumpUI)
    }
}

extension Collection where Element == DoseEntry {

    /**
     Maps a timeline of dose entries with overlapping start and end dates to a timeline of doses that represents actual insulin delivery.

     - returns: An array of reconciled insulin delivery history, as TempBasal and Bolus records
     */
    func reconciled() -> [DoseEntry] {

        var reconciled: [DoseEntry] = []

        var lastSuspend: DoseEntry?
        var lastBasal: DoseEntry?

        for dose in self {
            switch dose.type {
            case .bolus:
                reconciled.append(dose)
            case .basal, .tempBasal:
                if lastSuspend == nil, let last = lastBasal {
                    let endDate = Swift.min(last.endDate, dose.startDate)

                    // Ignore 0-duration doses
                    if endDate > last.startDate {
                        reconciled.append(last.trimmed(from: nil, to: endDate, syncIdentifier: last.syncIdentifier))
                    }
                } else if let suspend = lastSuspend, dose.type == .tempBasal {
                    // Handle missing resume. Basal following suspend, with no resume.
                    reconciled.append(DoseEntry(
                        type: suspend.type,
                        startDate: suspend.startDate,
                        endDate: dose.startDate,
                        value: suspend.value,
                        unit: suspend.unit,
                        description: suspend.description ?? dose.description,
                        syncIdentifier: suspend.syncIdentifier,
                        insulinType: suspend.insulinType,
                        automatic: suspend.automatic,
                        isMutable: suspend.isMutable,
                        wasProgrammedByPumpUI: suspend.wasProgrammedByPumpUI
                    ))
                    lastSuspend = nil
                }

                lastBasal = dose
            case .resume:
                if let suspend = lastSuspend {

                    reconciled.append(DoseEntry(
                        type: suspend.type,
                        startDate: suspend.startDate,
                        endDate: dose.startDate,
                        value: suspend.value,
                        unit: suspend.unit,
                        description: suspend.description ?? dose.description,
                        syncIdentifier: suspend.syncIdentifier,
                        insulinType: suspend.insulinType,
                        automatic: suspend.automatic,
                        isMutable: suspend.isMutable,
                        wasProgrammedByPumpUI: suspend.wasProgrammedByPumpUI
                    ))

                    lastSuspend = nil

                    // Continue temp basals that may have started before suspending
                    if let last = lastBasal {
                        if last.endDate > dose.endDate {
                            lastBasal = DoseEntry(
                                type: last.type,
                                startDate: dose.endDate,
                                endDate: last.endDate,
                                value: last.value,
                                unit: last.unit,
                                description: last.description,
                                // We intentionally use the resume's identifier, as the basal entry has already been entered
                                syncIdentifier: dose.syncIdentifier,
                                insulinType: last.insulinType,
                                automatic: last.automatic,
                                isMutable: last.isMutable,
                                wasProgrammedByPumpUI: last.wasProgrammedByPumpUI
                            )
                        } else {
                            lastBasal = nil
                        }
                    }
                }
            case .suspend:
                if let last = lastBasal {

                    reconciled.append(DoseEntry(
                        type: last.type,
                        startDate: last.startDate,
                        endDate: Swift.min(last.endDate, dose.startDate),
                        value: last.value,
                        unit: last.unit,
                        description: last.description,
                        syncIdentifier: last.syncIdentifier,
                        insulinType: last.insulinType,
                        automatic: last.automatic,
                        isMutable: last.isMutable,
                        wasProgrammedByPumpUI: last.wasProgrammedByPumpUI
                    ))

                    if last.endDate <= dose.startDate {
                        lastBasal = nil
                    }
                }

                lastSuspend = dose
            }
        }

        if let suspend = lastSuspend {
            reconciled.append(DoseEntry(
                type: suspend.type,
                startDate: suspend.startDate,
                endDate: nil,
                value: suspend.value,
                unit: suspend.unit,
                description: suspend.description,
                syncIdentifier: suspend.syncIdentifier,
                insulinType: suspend.insulinType,
                automatic: suspend.automatic,
                isMutable: true,  // Consider mutable until paired resume
                wasProgrammedByPumpUI: suspend.wasProgrammedByPumpUI
            ))
        } else if let last = lastBasal, last.endDate > last.startDate {
            reconciled.append(last)
        }

        return reconciled.map { $0.resolvingDelivery }
    }


    /// Fills any missing gaps in basal delivery with new doses based on the supplied basal history. Compared to `overlayBasalSchedule`, this uses a history of
    /// of basal rates, rather than a daily schedule, so it can work across multiple schedule changes.  This method is suitable for generating a display of basal delivery
    /// that includes scheduled and temp basals.
    ///
    /// - Parameters:
    ///   - basalTimeline: A history of scheduled basal rates. The first record should have a timestamp matching or earlier than the start date of the first DoseEntry in this array.
    ///   - endDate: Infill to this date, if supplied. If not supplied, infill will stop at the last DoseEntry.
    ///   - lastPumpEventsReconciliation: date at which pump manager has verified doses up to; doses with an end time of this or later are mutable
    ///   - gapPatchInterval: if the gap between two temp basals is less than this, then the start date of the second dose will be fudged to fill the gap. Used for display purposes.
    /// - Returns: An array of doses, with new doses created for any gaps between basalHistory.first.startDate and the end date.
    public func overlayBasal(_ basalTimeline: [AbsoluteScheduleValue<Double>], endDate: Date? = nil, lastPumpEventsReconciliation: Date, gapPatchInterval: TimeInterval = 0) -> [DoseEntry] {
        let dateFormatter = ISO8601DateFormatter()  // GMT-based ISO formatting

        guard basalTimeline.count > 0 else {
            return Array(self)
        }

        var newEntries = [DoseEntry]()
        var curBasalIdx = basalTimeline.startIndex
        var lastDate = basalTimeline[curBasalIdx].startDate

        func addBasalsBetween(startDate: Date, endDate: Date) {
            while lastDate < endDate {
                let entryEnd: Date
                let nextBasalIdx = curBasalIdx + 1
                let curRate = basalTimeline[curBasalIdx].value
                if nextBasalIdx < basalTimeline.endIndex && basalTimeline[nextBasalIdx].startDate < endDate {
                    entryEnd = Swift.max(startDate, basalTimeline[nextBasalIdx].startDate)
                    curBasalIdx = nextBasalIdx
                } else {
                    entryEnd = endDate
                }

                if lastDate != entryEnd {
                    if entryEnd.timeIntervalSince(lastDate).hours > 24 {
                        print("here")
                    }

                    let syncIdentifier = "BasalRateSchedule \(dateFormatter.string(from: lastDate)) \(dateFormatter.string(from: entryEnd))"

                    newEntries.append(
                        DoseEntry(
                            type: .basal,
                            startDate: lastDate,
                            endDate: entryEnd,
                            value: curRate,
                            unit: .unitsPerHour,
                            syncIdentifier: syncIdentifier,
                            scheduledBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: curRate),
                            isMutable: entryEnd >= lastPumpEventsReconciliation))

                    lastDate = entryEnd
                }
            }
        }

        for dose in self {
            switch dose.type {
            case .tempBasal, .basal, .suspend:
                var doseStart = dose.startDate
                if doseStart.timeIntervalSince(lastDate) > gapPatchInterval {
                    addBasalsBetween(startDate: lastDate, endDate: dose.startDate)
                } else {
                    doseStart = lastDate
                }
                newEntries.append(DoseEntry(
                    type: dose.type,
                    startDate: doseStart,
                    endDate: dose.endDate,
                    value: dose.value,
                    unit: dose.unit,
                    syncIdentifier: dose.syncIdentifier,
                    scheduledBasalRate: dose.scheduledBasalRate,
                    insulinType: dose.insulinType,
                    automatic: dose.automatic,
                    isMutable: dose.isMutable,
                    wasProgrammedByPumpUI: dose.wasProgrammedByPumpUI))
                lastDate = dose.endDate
            case .resume:
                assertionFailure("No resume events should be present in reconciled doses")
            case .bolus:
                newEntries.append(dose)
                break
            }
        }

        if let endDate, endDate > lastDate {
            addBasalsBetween(startDate: lastDate, endDate: endDate)
        }

        return newEntries
    }


    /// Applies the current basal schedule to a collection of reconciled doses in chronological order
    ///
    /// The scheduled basal rate is associated doses that override it, for later derivation of net delivery
    ///
    /// - Parameters:
    ///   - basalSchedule: The active basal schedule during the dose delivery
    ///   - start: The earliest date to apply the basal schedule
    ///   - end: The latest date to include. Doses must end before this time to be included.
    ///   - insertingBasalEntries: Whether basal doses should be created from the schedule. Pass true only for pump models that do not report their basal rates in event history.
    /// - Returns: An array of doses,
    public func oldOverlayBasalSchedule(_ basalSchedule: BasalRateSchedule, startingAt start: Date, endingAt end: Date = .distantFuture, insertingBasalEntries: Bool) -> [DoseEntry] {
        let dateFormatter = ISO8601DateFormatter()  // GMT-based ISO formatting
        var newEntries = [DoseEntry]()
        var lastBasal: DoseEntry?

        if insertingBasalEntries {
            // Create a placeholder entry at our start date, so we know the correct duration of the
            // inserted basal entries
            lastBasal = DoseEntry(resumeDate: start, automatic: true)
        }

        for dose in self {
            switch dose.type {
            case .tempBasal, .basal, .suspend:
                // Only include entries if they have ended by the end date, since they may be cancelled
                guard dose.endDate <= end else {
                    continue
                }

                if let lastBasal = lastBasal {
                    if insertingBasalEntries {
                        // For older pumps which don't report the start/end of scheduled basal delivery,
                        // generate a basal entry from the specified schedule.
                        for scheduled in basalSchedule.between(start: lastBasal.endDate, end: dose.startDate) {
                            // Generate a unique identifier based on the start/end timestamps
                            let start = Swift.max(lastBasal.endDate, scheduled.startDate)
                            let end = Swift.min(dose.startDate, scheduled.endDate)

                            guard end.timeIntervalSince(start) > .ulpOfOne else {
                                continue
                            }

                            let syncIdentifier = "BasalRateSchedule \(dateFormatter.string(from: start)) \(dateFormatter.string(from: end))"

                            newEntries.append(DoseEntry(
                                type: .basal,
                                startDate: start,
                                endDate: end,
                                value: scheduled.value,
                                unit: .unitsPerHour,
                                syncIdentifier: syncIdentifier,
                                scheduledBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: scheduled.value),
                                insulinType: lastBasal.insulinType,
                                automatic: lastBasal.automatic
                            ))
                        }
                    }
                }

                lastBasal = dose

                // Only include the last basal entry if has ended by our end date
                if let lastBasal = lastBasal {
                    newEntries.append(lastBasal)
                }
            case .resume:
                assertionFailure("No resume events should be present in reconciled doses")
            case .bolus:
                newEntries.append(dose)
            }
        }

        return newEntries
    }

    /// Creates an array of DoseEntry values by unioning another array, de-duplicating by syncIdentifier
    ///
    /// - Parameter otherDoses: An array of doses to union
    /// - Returns: A new array of doses
    func appendedUnion(with otherDoses: [DoseEntry]) -> [DoseEntry] {
        var union: [DoseEntry] = []
        var syncIdentifiers: Set<String> = []

        for dose in (self + otherDoses) {
            if let syncIdentifier = dose.syncIdentifier {
                let (inserted, _) = syncIdentifiers.insert(syncIdentifier)
                if !inserted {
                    continue
                }
            }

            union.append(dose)
        }

        return union
    }
}
