//
//  TemporaryScheduleOverrideTests.swift
//  LoopKitTests
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopAlgorithm

@testable import LoopKit

fileprivate struct SimpleInsulinDose: InsulinDose {
    var deliveryType: InsulinDeliveryType
    var startDate: Date
    var endDate: Date
    var volume: Double
    var insulinModel: InsulinModel
}

fileprivate struct StoredDataAlgorithmInput: AlgorithmInput {
    typealias CarbType = StoredCarbEntry

    typealias GlucoseType = StoredGlucoseSample

    typealias InsulinDoseType = SimpleInsulinDose

    var glucoseHistory: [StoredGlucoseSample]
    
    var doses: [SimpleInsulinDose]

    var carbEntries: [StoredCarbEntry]
    
    var predictionStart: Date
    
    var basal: [AbsoluteScheduleValue<Double>]
    
    var sensitivity: [AbsoluteScheduleValue<LoopQuantity>]
    
    var carbRatio: [AbsoluteScheduleValue<Double>]
    
    var target: GlucoseRangeTimeline
    
    var suspendThreshold: LoopQuantity?
    
    var maxBolus: Double
    
    var maxBasalRate: Double
    
    var useIntegralRetrospectiveCorrection: Bool
    
    var includePositiveVelocityAndRC: Bool
    
    var carbAbsorptionModel: CarbAbsorptionModel
    
    var recommendationInsulinModel: InsulinModel
    
    var recommendationType: DoseRecommendationType
    
    var automaticBolusApplicationFactor: Double?

    let useMidAbsorptionISF: Bool = true
}

extension TimeZone {
    static var fixtureTimeZone: TimeZone {
        return TimeZone(secondsFromGMT: 25200)! // -0700
    }
    
    static var utcTimeZone: TimeZone {
        return TimeZone(secondsFromGMT: 0)!
    }
}

extension ISO8601DateFormatter {
    static func fixtureFormatter(timeZone: TimeZone = .fixtureTimeZone) -> Self {
        let formatter = self.init()

        formatter.formatOptions = .withInternetDateTime
        formatter.formatOptions.subtract(.withTimeZone)
        formatter.timeZone = timeZone

        return formatter
    }
}

class TemporaryScheduleOverrideTests: XCTestCase {

    let dateFormatter = ISO8601DateFormatter.localTimeDate()
    let epsilon = 1e-6

    let basalRateSchedule = BasalRateSchedule(dailyItems: [
        RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
        RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
        RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
    ])!

    private func date(at time: String) -> Date {
        return dateFormatter.date(from: "2019-01-01T\(time):00")!
    }

    private func basalUpOverride(start: String, end: String) -> TemporaryScheduleOverride {
        return TemporaryScheduleOverride(
            context: .custom,
            settings: TemporaryScheduleOverrideSettings(
                unit: .milligramsPerDeciliter,
                targetRange: nil,
                insulinNeedsScaleFactor: 1.5
            ),
            startDate: date(at: start),
            duration: .finite(date(at: end).timeIntervalSince(date(at: start))),
            enactTrigger: .local,
            syncIdentifier: UUID()
        )
    }

    private func applyingActiveBasalOverride(from start: String, to end: String, on schedule: BasalRateSchedule, referenceDate: Date? = nil) -> BasalRateSchedule {
        let override = basalUpOverride(start: start, end: end)
        let referenceDate = referenceDate ?? override.startDate
        return schedule.applyingBasalRateMultiplier(from: override, relativeTo: referenceDate)
    }

    // Override start aligns with schedule item start
    func testBasalRateScheduleOverrideStartTimeMatch() {
        let overrideBasalSchedule = applyingActiveBasalOverride(from: "00:00", to: "01:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(1), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overrideBasalSchedule.equals(expected, accuracy: epsilon))
    }

    // Override contained fully within a schedule item
    func testBasalRateScheduleOverrideContained() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "04:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(4), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    // Override end aligns with schedule item start
    func testBasalRateScheduleOverrideEndTimeMatch() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "06:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    // Override completely encapsulates schedule item
    func testBasalRateScheduleOverrideEncapsulate() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "22:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.5),
            RepeatingScheduleValue(startTime: .hours(22), value: 1.0),
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testSingleBasalRateSchedule() {
        let basalRateSchedule = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.0)
        ])!
        let overridden = applyingActiveBasalOverride(from: "08:00", to: "12:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.0),
            RepeatingScheduleValue(startTime: .hours(8), value: 1.5),
            RepeatingScheduleValue(startTime: .hours(12), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testOverrideCrossingMidnight() {
        var override = basalUpOverride(start: "22:00", end: "23:00")
        override.duration += .hours(5) // override goes from 10pm to 4am of the next day

        let overridden = basalRateSchedule.applyingBasalRateMultiplier(from: override, relativeTo: date(at: "22:00"))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(4), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0),
            RepeatingScheduleValue(startTime: .hours(22), value: 1.5)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testMultiDayOverride() {
        var override = basalUpOverride(start: "02:00", end: "22:00")
        override.duration += .hours(48) // override goes from 2am until 10pm two days later

        let overridden = basalRateSchedule.applyingBasalRateMultiplier(
            from: override,
            relativeTo: date(at: "02:00") + .hours(24)
        )

        // expect full schedule override; start/end dates are too distant to have an effect
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.5)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testOutdatedOverride() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "04:00", on: basalRateSchedule,
                                                     referenceDate: date(at: "12:00").addingTimeInterval(.hours(24)))
        let expected = basalRateSchedule

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testFarFutureOverride() {
        let overridden = applyingActiveBasalOverride(from: "10:00", to: "12:00", on: basalRateSchedule,
                                                     referenceDate: date(at: "02:00").addingTimeInterval(-.hours(24)))
        let expected = basalRateSchedule

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testIndefiniteOverride() {
        var override = basalUpOverride(start: "02:00", end: "22:00")
        override.duration = .indefinite
        let overridden = basalRateSchedule.applyingBasalRateMultiplier(from: override, relativeTo: date(at: "02:00"))

        // expect full schedule overridden
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.5)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }
    
    func testDurationIsInfinite() {
        let tempOverride = TemporaryScheduleOverride(context: .legacyWorkout,
                                                     settings: .init(unit: .milligramsPerDeciliter, targetRange: DoubleRange(minValue: 120, maxValue: 150)),
                                                     startDate: Date(),
                                                     duration: .indefinite,
                                                     enactTrigger: .local,
                                                     syncIdentifier: UUID())
        XCTAssertTrue(tempOverride.duration.isInfinite)
    }

    func testOverrideScheduleAnnotatingReservoirSplitsDose() {
        let schedule = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 0.225),
            RepeatingScheduleValue(startTime: 3600.0, value: 0.18000000000000002),
            RepeatingScheduleValue(startTime: 10800.0, value: 0.135),
            RepeatingScheduleValue(startTime: 12689.855275034904, value: 0.15),
            RepeatingScheduleValue(startTime: 21600.0, value: 0.2),
            RepeatingScheduleValue(startTime: 32400.0, value: 0.2),
            RepeatingScheduleValue(startTime: 50400.0, value: 0.2),
            RepeatingScheduleValue(startTime: 52403.79680299759, value: 0.16000000000000003),
            RepeatingScheduleValue(startTime: 63743.58014559746, value: 0.2),
            RepeatingScheduleValue(startTime: 63743.58014583588, value: 0.16000000000000003),
            RepeatingScheduleValue(startTime: 69968.05249071121, value: 0.2),
            RepeatingScheduleValue(startTime: 69968.05249094963, value: 0.18000000000000002),
            RepeatingScheduleValue(startTime: 79200.0, value: 0.225),
        ])!

        let start = date(at: "19:25")

        let dose = FixtureInsulinDose(
            deliveryType: .basal,
            startDate: start,
            endDate: date(at: "19:30"),
            volume: 0.8,
            insulinType: .novolog
        )

        let timeline = schedule.between(start: start, end: start.addingTimeInterval(InsulinMath.longestInsulinActivityDuration))

        let annotated = [dose].annotated(with: timeline)

        XCTAssertEqual(3, annotated.count)
        XCTAssertEqual(dose.volume, annotated.map { $0.volume }.reduce(0, +))
    }

    // MARK: - Target range tests

    func testActiveTargetRangeOverride() {
        let overrideRange = DoubleRange(minValue: 120, maxValue: 140)
        let overrideStart = Date()
        let overrideDuration = TimeInterval(hours: 4)
        let settings = TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter, targetRange: overrideRange)
        let override = TemporaryScheduleOverride(context: .custom, settings: settings, startDate: overrideStart, duration: .finite(overrideDuration), enactTrigger: .local, syncIdentifier: UUID())
        let normalRange = DoubleRange(minValue: 95, maxValue: 105)
        let rangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: normalRange)])!.applyingOverride(override)

        XCTAssertEqual(rangeSchedule.value(at: overrideStart), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration / 2), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration + .hours(2)), overrideRange)
    }

    func testFutureTargetRangeOverride() {
        let overrideRange = DoubleRange(minValue: 120, maxValue: 140)
        let overrideStart = Date() + .hours(2)
        let overrideDuration = TimeInterval(hours: 4)
        let settings = TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter, targetRange: overrideRange)
        let futureOverride = TemporaryScheduleOverride(context: .custom, settings: settings, startDate: overrideStart, duration: .finite(overrideDuration), enactTrigger: .local, syncIdentifier: UUID())
        let normalRange = DoubleRange(minValue: 95, maxValue: 105)
        let rangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: normalRange)])!.applyingOverride(futureOverride)

        XCTAssertEqual(rangeSchedule.value(at: overrideStart + .minutes(-5)), normalRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration + .hours(2)), overrideRange)
    }

    func testTimelineSensitivityApplication() {
        let timeline = [
            AbsoluteScheduleValue(startDate: .t(1) , endDate: .t(2), value: 50.0),
            AbsoluteScheduleValue(startDate: .t(2) , endDate: .t(3), value: 75.0),
            AbsoluteScheduleValue(startDate: .t(3) , endDate: .t(4), value: 25.0),
            AbsoluteScheduleValue(startDate: .t(4) , endDate: .t(5), value: 100.0),
        ]

        let overrides: [TemporaryScheduleOverride] = [
            .custom(scale: 0.5, start: .t(2.5), end: .t(3.5)),
            .custom(scale: 0.2, start: .t(4.5), end: .t(5))
        ]

        let applied = overrides.applySensitivity(over: timeline)

        let times = applied.map { $0.startDate }
        let expectedTimes: [Date] = [.t(1), .t(2), .t(2.5), .t(3), .t(3.5), .t(4), .t(4.5)]
        XCTAssertEqual(expectedTimes, times)

        let values = applied.map { $0.value }
        let expectedValues: [Double] = [50, 75, 150, 50, 25, 100, 500]
        XCTAssertEqual(expectedValues, values)
    }

    func testTimelineSensitivityApplicationStartingAtSameTime() {
        let timeline = [
            AbsoluteScheduleValue(startDate: .t(1) , endDate: .t(2), value: 50.0),
        ]

        let overrides: [TemporaryScheduleOverride] = [
            .custom(scale: 0.5, start: .t(1), end: .t(1.5))
        ]

        let applied = overrides.applySensitivity(over: timeline)

        let times = applied.map { $0.startDate }
        let expectedTimes: [Date] = [.t(1), .t(1.5)]
        XCTAssertEqual(expectedTimes, times)

        let values = applied.map { $0.value }
        let expectedValues: [Double] = [100, 50]
        XCTAssertEqual(expectedValues, values)
    }

    func testTimelineSensitivityApplicationEndingAtSameTime() {
        let timeline = [
            AbsoluteScheduleValue(startDate: .t(1) , endDate: .t(2), value: 50.0),
            AbsoluteScheduleValue(startDate: .t(2) , endDate: .t(3), value: 120.0),
        ]

        let overrides: [TemporaryScheduleOverride] = [
            .custom(scale: 0.5, start: .t(1.5), end: .t(2))
        ]

        let applied = overrides.applySensitivity(over: timeline)

        let times = applied.map { $0.startDate }
        let expectedTimes: [Date] = [.t(1), .t(1.5), .t(2)]
        XCTAssertEqual(expectedTimes, times)

        let values = applied.map { $0.value }
        let expectedValues: [Double] = [50, 100, 120]
        XCTAssertEqual(expectedValues, values)
    }

    func testTimelineSensitivityApplicationInMiddleOfTimeRange() {
        let timeline = [
            AbsoluteScheduleValue(startDate: .t(1) , endDate: .t(3), value: 50.0),
        ]

        let overrides: [TemporaryScheduleOverride] = [
            .custom(scale: 0.5, start: .t(1.5), end: .t(2))
        ]

        let applied = overrides.applySensitivity(over: timeline)

        let times = applied.map { $0.startDate }
        let expectedTimes: [Date] = [.t(1), .t(1.5), .t(2)]
        XCTAssertEqual(expectedTimes, times)

        let values = applied.map { $0.value }
        let expectedValues: [Double] = [50, 100, 50]
        XCTAssertEqual(expectedValues, values)
    }

    func testTargetOverridePremeal() {
        let scheduledRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 100)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 110)
        let overrideRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 90)

        let timeline = [
            AbsoluteScheduleValue(
                startDate: .t(0),
                endDate: .t(4),
                value: scheduledRange
            ),
        ]

        var overrides: [TemporaryScheduleOverride] = [
            .init(
                context: .preMeal,
                settings: .init(targetRange: overrideRange),
                startDate: .t(2),
                duration: .finite(.hours(1)),
                enactTrigger: .local,
                syncIdentifier: UUID()
            )
        ]

        // Test override in future
        var applied = overrides.applyTarget(over: timeline, at: .t(0))

        var times = applied.map { $0.startDate }
        var expectedTimes: [Date] = [.t(0), .t(2)]
        XCTAssertEqual(expectedTimes, times)
        XCTAssertEqual(.t(4), applied.last!.endDate)

        var values = applied.map { $0.value }
        var expectedValues: [ClosedRange<LoopQuantity>] = [
            scheduledRange,
            overrideRange
        ]
        XCTAssertEqual(expectedValues, values)

        // Test override currently running
        applied = overrides.applyTarget(over: timeline, at: .t(2.5))

        times = applied.map { $0.startDate }
        expectedTimes = [.t(0), .t(2)]
        XCTAssertEqual(expectedTimes, times)
        XCTAssertEqual(.t(4), applied.last!.endDate)

        values = applied.map { $0.value }
        expectedValues = [
            scheduledRange,
            overrideRange
        ]
        XCTAssertEqual(expectedValues, values)

        // Test override expired
        applied = overrides.applyTarget(over: timeline, at: .t(3.5))

        times = applied.map { $0.startDate }
        expectedTimes = [.t(0)]
        XCTAssertEqual(expectedTimes, times)
        XCTAssertEqual(.t(4), applied.last!.endDate)

        values = applied.map { $0.value }
        expectedValues = [
            scheduledRange
        ]
        XCTAssertEqual(expectedValues, values)

        // Test override canceled 30 minutes after start (at 2.5 hours)
        overrides[0].actualEnd = .early(.t(2.5))
        applied = overrides.applyTarget(over: timeline, at: .t(2.8))

        times = applied.map { $0.startDate }
        XCTAssertEqual([.t(0)], times)
        XCTAssertEqual(.t(4), applied.last!.endDate)

        values = applied.map { $0.value }
        XCTAssertEqual([scheduledRange], values)
    }
    
    func testTargetOverrideWorkoutPrediction() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let now = startOfDay.addingTimeInterval(.hours(12))
        let scheduledRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 100)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 110)
        let overrideRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 140)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 160)

        let overrideDuration = TimeInterval(hours: 2)
        var overrides: [TemporaryScheduleOverride] = [
            .init(
                context: .legacyWorkout,
                settings: .init(targetRange: overrideRange),
                startDate: now,
                duration: .finite(overrideDuration),
                enactTrigger: .local,
                syncIdentifier: UUID()
            )
        ]

        // sensitivity with overrides
        let sensitivity1Value = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 45)
        let sensitivity2Value = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 55)
        let sensitivity1End = TimeInterval(hours: 9)
        let sensitivity2End = TimeInterval(hours: 24)
        let sensitivity: [AbsoluteScheduleValue<LoopQuantity>] = [
            AbsoluteScheduleValue(startDate: startOfDay, endDate: startOfDay.addingTimeInterval(sensitivity1End), value: sensitivity1Value),
            AbsoluteScheduleValue(startDate: startOfDay.addingTimeInterval(.hours(9)), endDate: startOfDay.addingTimeInterval(sensitivity2End), value: sensitivity2Value),
        ]
        let sensitivityWithOverrides = overrides.applySensitivity(over: sensitivity)
        XCTAssertEqual(sensitivityWithOverrides.count, 4)
        XCTAssertEqual(sensitivityWithOverrides[0].startDate, startOfDay)
        XCTAssertEqual(sensitivityWithOverrides[0].endDate, startOfDay.addingTimeInterval(sensitivity1End))
        XCTAssertEqual(sensitivityWithOverrides[0].value, sensitivity1Value)
        XCTAssertEqual(sensitivityWithOverrides[1].startDate, startOfDay.addingTimeInterval(sensitivity1End))
        XCTAssertEqual(sensitivityWithOverrides[1].endDate, now)
        XCTAssertEqual(sensitivityWithOverrides[1].value, sensitivity2Value)
        XCTAssertEqual(sensitivityWithOverrides[2].startDate, now)
        XCTAssertEqual(sensitivityWithOverrides[2].endDate, now.addingTimeInterval(overrideDuration))
        XCTAssertEqual(sensitivityWithOverrides[2].value, sensitivity2Value)
        XCTAssertEqual(sensitivityWithOverrides[3].startDate, now.addingTimeInterval(overrideDuration))
        XCTAssertEqual(sensitivityWithOverrides[3].endDate, startOfDay.addingTimeInterval(sensitivity2End))
        XCTAssertEqual(sensitivityWithOverrides[3].value, sensitivity2Value)

        // Basal with overrides
        let basal1Value = 1.0
        let basal2Value = 0.85
        let basal1End = TimeInterval(hours: 17)
        let basal2End = TimeInterval(hours: 24)
        let basal: [AbsoluteScheduleValue<Double>] = [
            AbsoluteScheduleValue(startDate: startOfDay, endDate: startOfDay.addingTimeInterval(basal1End), value: basal1Value),
            AbsoluteScheduleValue(startDate: startOfDay.addingTimeInterval(basal1End), endDate: startOfDay.addingTimeInterval(basal2End), value: basal2Value),
        ]
        let basalWithOverrides = overrides.applyBasal(over: basal)
        XCTAssertEqual(basalWithOverrides.count, 4)
        XCTAssertEqual(basalWithOverrides[0].startDate, startOfDay)
        XCTAssertEqual(basalWithOverrides[0].endDate, now)
        XCTAssertEqual(basalWithOverrides[0].value, basal1Value)
        XCTAssertEqual(basalWithOverrides[1].startDate, now)
        XCTAssertEqual(basalWithOverrides[1].endDate, now.addingTimeInterval(overrideDuration))
        XCTAssertEqual(basalWithOverrides[1].value, basal1Value)
        XCTAssertEqual(basalWithOverrides[2].startDate, now.addingTimeInterval(overrideDuration))
        XCTAssertEqual(basalWithOverrides[2].endDate, startOfDay.addingTimeInterval(basal1End))
        XCTAssertEqual(basalWithOverrides[2].value, basal1Value)
        XCTAssertEqual(basalWithOverrides[3].startDate, startOfDay.addingTimeInterval(basal1End))
        XCTAssertEqual(basalWithOverrides[3].endDate, startOfDay.addingTimeInterval(basal2End))
        XCTAssertEqual(basalWithOverrides[3].value, basal2Value)
        
        // carb ratio with overrides
        let carbRatio1Value = 10.0
        let carbRatio1End = TimeInterval(hours: 24)
        let carbRatio: [AbsoluteScheduleValue<Double>] = [
            AbsoluteScheduleValue(startDate: startOfDay, endDate: startOfDay.addingTimeInterval(carbRatio1End), value: carbRatio1Value),
        ]
        let carbRatioWithOverrides = overrides.applyBasal(over: carbRatio)
        XCTAssertEqual(carbRatioWithOverrides.count, 3)
        XCTAssertEqual(carbRatioWithOverrides[0].startDate, startOfDay)
        XCTAssertEqual(carbRatioWithOverrides[0].endDate, now)
        XCTAssertEqual(carbRatioWithOverrides[0].value, carbRatio1Value)
        XCTAssertEqual(carbRatioWithOverrides[1].startDate, now)
        XCTAssertEqual(carbRatioWithOverrides[1].endDate, now.addingTimeInterval(overrideDuration))
        XCTAssertEqual(carbRatioWithOverrides[1].value, carbRatio1Value)
        XCTAssertEqual(carbRatioWithOverrides[2].startDate, now.addingTimeInterval(overrideDuration))
        XCTAssertEqual(carbRatioWithOverrides[2].endDate, startOfDay.addingTimeInterval(carbRatio1End))
        XCTAssertEqual(carbRatioWithOverrides[2].value, carbRatio1Value)
        
        // target with overrides
        let targetDuration = TimeInterval.hours(8)
        let target = [
            AbsoluteScheduleValue(
                startDate: now.addingTimeInterval(-overrideDuration),
                endDate: now.addingTimeInterval(targetDuration),
                value: scheduledRange
            ),
        ]
        
        var targetWithOverrides = overrides.applyTarget(over: target, at: now)
        var expetedRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 100.0)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 110.0)
        XCTAssertEqual(targetWithOverrides.count, 2)
        XCTAssertEqual(targetWithOverrides.first?.value, expetedRange)
        XCTAssertEqual(targetWithOverrides.first?.startDate, now.addingTimeInterval(-overrideDuration))
        expetedRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 140.0)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 160.0)
        XCTAssertEqual(targetWithOverrides.first?.endDate, now)
        XCTAssertEqual(targetWithOverrides.last?.value, expetedRange)
        XCTAssertEqual(targetWithOverrides.last?.startDate, now)
        XCTAssertEqual(targetWithOverrides.last?.endDate, now.addingTimeInterval(targetDuration))
        
        // algorithm input
        let doses: [DoseEntry] = [
            DoseEntry(type: .tempBasal, startDate: now.addingTimeInterval(-overrideDuration), value: 0, unit: .unitsPerHour),
            DoseEntry(type: .tempBasal, startDate: now.addingTimeInterval(-(overrideDuration - .minutes(30)*1)), value: 1.15, unit: .unitsPerHour),
            DoseEntry(type: .basal, startDate: now.addingTimeInterval(-(overrideDuration - .minutes(30)*2)), value: 1, unit: .unitsPerHour),
            DoseEntry(type: .tempBasal, startDate: now.addingTimeInterval(-(overrideDuration - .minutes(30)*3)), value: 0.95, unit: .unitsPerHour),
            DoseEntry(type: .tempBasal, startDate: now.addingTimeInterval(-(overrideDuration - .minutes(30)*4)), value: 0.80, unit: .unitsPerHour),
        ]
        let dosesWithModel = doses.map { SimpleInsulinDose(deliveryType: $0.type == .bolus ? .bolus : .basal, startDate: $0.startDate, endDate: $0.endDate, volume: $0.deliveredUnits ?? $0.programmedUnits, insulinModel: ExponentialInsulinModelPreset.rapidActingAdult.model) }

        let correctionRange = target.closestPrior(to: now)?.value
        let carbEntry = StoredCarbEntry(startDate: now, quantity: LoopQuantity(unit: .gram, doubleValue: 10.0))
        
        let glucoseValues: [Double] = [146, 143, 141, 137, 134, 131, 128, 124, 121, 117,
                                       114, 110, 107, 104, 101, 98, 95, 92, 90, 88,
                                       86, 84, 83, 82, 81, 80, 80, 80, 80, 81,
                                       81, 81, 82, 82, 83, 84, 85, 85, 87, 87,
                                       89, 89, 90, 91, 91, 92, 94, 94, 98]
        let timeIntervalStepSize = TimeInterval(minutes: 5)
        var glucoseHistory: [StoredGlucoseSample] = []
        var currentDate = Date().addingTimeInterval(-1*timeIntervalStepSize*Double(glucoseValues.count))
        for (index, glucoseValue) in glucoseValues.enumerated() {
            let uuid = UUID()
            currentDate = currentDate.addingTimeInterval(timeIntervalStepSize)
            var trendRate = 4.0/timeIntervalStepSize
            if index < glucoseValues.count - 1 {
                trendRate = (glucoseValues[index+1] - glucoseValues[index])/timeIntervalStepSize
            }
            glucoseHistory.append(
                StoredGlucoseSample(uuid: uuid,
                                    provenanceIdentifier: "org.tidepool.Loop",
                                    syncIdentifier: uuid.uuidString,
                                    syncVersion: 1,
                                    startDate: currentDate,
                                    quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: glucoseValue),
                                    trend: trendRate > 0 ? .upUp : .downDown,
                                    trendRate: LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: trendRate)))
        }
        
        let effectiveBolusApplicationFactor: Double? = LoopAlgorithm.defaultBolusPartialApplicationFactor
        
        let input = StoredDataAlgorithmInput(
            glucoseHistory: glucoseHistory,
            doses: dosesWithModel,
            carbEntries: [carbEntry],
            predictionStart: now,
            basal: basalWithOverrides,
            sensitivity: sensitivityWithOverrides,
            carbRatio: carbRatioWithOverrides,
            target: targetWithOverrides,
            suspendThreshold: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 75),
            maxBolus: 10,
            maxBasalRate: 5,
            useIntegralRetrospectiveCorrection: false,
            includePositiveVelocityAndRC: true,
            carbAbsorptionModel: .linear,
            recommendationInsulinModel: ExponentialInsulinModel(actionDuration: 21600, peakActivityTime: 4500, delay: 600),
            recommendationType: .manualBolus,
            automaticBolusApplicationFactor: effectiveBolusApplicationFactor)
        
        let prediction = LoopAlgorithm.generatePrediction(
            start: input.predictionStart,
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            algorithmEffectsOptions: .all,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection,
            includingPositiveVelocityAndRC: input.includePositiveVelocityAndRC,
            useMidAbsorptionISF: input.useMidAbsorptionISF,
            carbAbsorptionModel: input.carbAbsorptionModel.model)
        print("!!! prediction.glucose.last!.quantity \(prediction.glucose.last!.quantity)")
        XCTAssertTrue(prediction.glucose.last!.quantity > overrideRange.lowerBound)
        XCTAssertTrue(prediction.glucose.last!.quantity < overrideRange.upperBound)
    }

    func testPreMealPreset() {
        let now = ISO8601DateFormatter().date(from: "2020-03-11T12:13:14-0700")!

        var input = AlgorithmInputFixture.mock(for: now)
        input.recommendationType = .tempBasal

        func d(_ interval: TimeInterval) -> Date {
            return now.addingTimeInterval(interval)
        }

        // Flat, in range bg.
        input.glucoseHistory = [
            FixtureGlucoseSample(startDate: d(.minutes(-19)), quantity: .glucose(value: 105)),
            FixtureGlucoseSample(startDate: d(.minutes(-14)), quantity: .glucose(value: 105)),
            FixtureGlucoseSample(startDate: d(.minutes(-9)), quantity: .glucose(value: 105)),
            FixtureGlucoseSample(startDate: d(.minutes(-4)), quantity: .glucose(value: 105)),
        ]

        let scheduledRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 100)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 110)
        let overrideRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 90)

        let overrideStartTime = d(.minutes(-10))

        let overrides: [TemporaryScheduleOverride] = [
            .init(
                context: .preMeal,
                settings: .init(targetRange: overrideRange),
                startDate: overrideStartTime,
                duration: .finite(.hours(1)),
                enactTrigger: .local,
                syncIdentifier: UUID()
            )
        ]

        let targetTimeline: [AbsoluteScheduleValue<ClosedRange<LoopQuantity>>] = [
            AbsoluteScheduleValue(startDate: d(.hours(-2)), endDate: d(.hours(10)), value: scheduledRange)
        ]

        input.target = overrides.applyTarget(over: targetTimeline, at: now)

        input.doses = []
        input.carbEntries = []

        let output = LoopAlgorithm.run(input: input)

        let recommendedRate = output.recommendation!.automatic!.basalAdjustment!.unitsPerHour
        let activeInsulin = output.activeInsulin!
        XCTAssertEqual(activeInsulin, 0)
        XCTAssertEqual(recommendedRate, 1.727, accuracy: 0.01)
    }

}

extension Date {
    static func t(_ hours: Double) -> Date {
        return .init(timeIntervalSince1970: .hours(hours))
    }
}

extension TemporaryScheduleOverride {
    static func custom(scale: Double? = nil, target: ClosedRange<Double>? = nil, start: Date, end: Date?) -> TemporaryScheduleOverride {
        let targetRange = target.map {
            ClosedRange(uncheckedBounds: (
                lower: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.lowerBound),
                upper: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.upperBound)))
        }
        let settings = TemporaryScheduleOverrideSettings(targetRange: targetRange, insulinNeedsScaleFactor: scale)
        let duration: TimeInterval? = end.map { $0.timeIntervalSince(start) }
        return TemporaryScheduleOverride(
            context: .custom,
            settings: settings,
            startDate: start,
            duration: duration != nil ? .finite(duration!) : .indefinite,
            enactTrigger: .local,
            syncIdentifier: UUID()
        )
    }
}

class TemporaryScheduleOverrideContextCodableTests: XCTestCase {
    func testCodablePreMeal() throws {
        try assertTemporaryScheduleOverrideContextCodable(.preMeal, encodesJSON: """
{
  "context" : "preMeal"
}
"""
        )
    }

    func testCodableLegacyWorkout() throws {
        try assertTemporaryScheduleOverrideContextCodable(.legacyWorkout, encodesJSON: """
{
  "context" : "legacyWorkout"
}
"""
        )
    }

    func testCodablePreset() throws {
        let preset = TemporaryScheduleOverridePreset(id: UUID(uuidString: "238E41EA-9576-4981-A1A4-51E10228584F")!,
                                                     symbol: "🚀",
                                                     name: "Rocket",
                                                     settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                 targetRange: DoubleRange(minValue: 90, maxValue: 100)),
                                                     duration: .indefinite)
        try assertTemporaryScheduleOverrideContextCodable(.preset(preset), encodesJSON: """
{
  "context" : {
    "preset" : {
      "preset" : {
        "duration" : "indefinite",
        "id" : "238E41EA-9576-4981-A1A4-51E10228584F",
        "name" : "Rocket",
        "settings" : {
          "targetRangeInMgdl" : {
            "maxValue" : 100,
            "minValue" : 90
          }
        },
        "symbol" : "🚀"
      }
    }
  }
}
"""
        )
    }

    func testCodableCustom() throws {
        try assertTemporaryScheduleOverrideContextCodable(.custom, encodesJSON: """
{
  "context" : "custom"
}
"""
        )
    }

    private func assertTemporaryScheduleOverrideContextCodable(_ original: TemporaryScheduleOverride.Context, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(context: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.context, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private struct TestContainer: Codable, Equatable {
        let context: TemporaryScheduleOverride.Context
    }
}

class TemporaryScheduleOverrideEnactTriggerCodableTests: XCTestCase {
    func testCodableLocal() throws {
        try assertTemporaryScheduleOverrideEnactTriggerCodable(.local, encodesJSON: """
{
  "enactTrigger" : "local"
}
"""
        )
    }

    func testCodableRemote() throws {
        try assertTemporaryScheduleOverrideEnactTriggerCodable(.remote("address"), encodesJSON: """
{
  "enactTrigger" : {
    "remote" : {
      "address" : "address"
    }
  }
}
"""
        )
    }

    private func assertTemporaryScheduleOverrideEnactTriggerCodable(_ original: TemporaryScheduleOverride.EnactTrigger, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(enactTrigger: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.enactTrigger, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private struct TestContainer: Codable, Equatable {
        let enactTrigger: TemporaryScheduleOverride.EnactTrigger
    }
}

class TemporaryScheduleOverrideDurationCodableTests: XCTestCase {
    func testCodableFinite() throws {
        try assertTemporaryScheduleOverrideDurationCodable(.finite(.hours(2.5)), encodesJSON: """
{
  "duration" : {
    "finite" : {
      "duration" : 9000
    }
  }
}
"""
        )
    }

    func testCodableIndefinite() throws {
        try assertTemporaryScheduleOverrideDurationCodable(.indefinite, encodesJSON: """
{
  "duration" : "indefinite"
}
"""
        )
    }

    private func assertTemporaryScheduleOverrideDurationCodable(_ original: TemporaryScheduleOverride.Duration, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(duration: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.duration, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private struct TestContainer: Codable, Equatable {
        let duration: TemporaryScheduleOverride.Duration
    }
}

private extension TemporaryScheduleOverride.Duration {
    static func += (lhs: inout TemporaryScheduleOverride.Duration, rhs: TimeInterval) {
        switch lhs {
        case .finite(let interval):
            lhs = .finite(interval + rhs)
        case .indefinite:
            return
        }
    }
}

class TemporaryOverrideEndCodableTests: XCTestCase {
    var dateFormatter = ISO8601DateFormatter.fixtureFormatter()
    
    private func date(at time: String) -> Date {
        return dateFormatter.date(from: "2019-01-01T\(time):00")!
    }
    
    func testCodableOverrideEarlyEnd() throws {
        let end = End.early(date(at: "02:00"))
        try assertEndCodable(end, encodesJSON: """
{
  "end" : {
    "date" : 567975600,
    "type" : "early"
  }
}
"""
        )
    }
    
    func testCodableOverrideNaturalEnd() throws {
        let end = End.natural
        try assertEndCodable(end, encodesJSON: """
{
  "end" : {
    "type" : "natural"
  }
}
"""
        )
    }
    
    func testCodableOverrideDeleted() throws {
        let end = End.deleted
        try assertEndCodable(end, encodesJSON: """
{
  "end" : {
    "type" : "deleted"
  }
}
"""
        )
    }
    
    private func assertEndCodable(_ original: End, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(end: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.end, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private struct TestContainer: Codable, Equatable {
        let end: End
    }
}

extension AlgorithmInputFixture {
    /// Mocks stable, in range glucose, no insulin, no carbs, with reasonable settings
    static func mock(for now: Date = Date()) -> AlgorithmInputFixture {

        func d(_ interval: TimeInterval) -> Date {
            return now.addingTimeInterval(interval)
        }

        let forecastEnd = now.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration).dateCeiledToTimeInterval(GlucoseMath.defaultDelta)

        return AlgorithmInputFixture(
            predictionStart: now,
            glucoseHistory: [
                FixtureGlucoseSample(startDate: d(.minutes(-19)), quantity: .glucose(value: 100)),
                FixtureGlucoseSample(startDate: d(.minutes(-14)), quantity: .glucose(value: 120)),
                FixtureGlucoseSample(startDate: d(.minutes(-9)), quantity: .glucose(value: 140)),
                FixtureGlucoseSample(startDate: d(.minutes(-4)), quantity: .glucose(value: 160)),
            ],
            doses: [],
            carbEntries: [],
            basal: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now, value: 1.0)],
            sensitivity: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: forecastEnd, value: .glucose(value: 55))],
            carbRatio: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now, value: 10)],
            target: [AbsoluteScheduleValue(startDate: d(.hours(-10)), endDate: now, value: ClosedRange(uncheckedBounds: (lower: .glucose(value: 100), upper: .glucose(value: 110))))],
            suspendThreshold: .glucose(value: 65),
            maxBolus: 6,
            maxBasalRate: 8,
            recommendationInsulinType: .novolog,
            recommendationType: .tempBasal
        )
    }
}

extension LoopQuantity {
    static func glucose(value: Double) -> LoopQuantity {
        return .init(unit: .milligramsPerDeciliter, doubleValue: value)
    }

    static func carbs(value: Double) -> LoopQuantity {
        return .init(unit: .gram, doubleValue: value)
    }

}

