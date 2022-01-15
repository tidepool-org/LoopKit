//
//  DoseStoreTests.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import XCTest
import CoreData
import HealthKit
@testable import LoopKit

class DoseStoreTests: PersistenceControllerTestCase {

    func testEmptyDoseStoreReturnsZeroInsulinOnBoard() {
        // 1. Create a DoseStore
        let healthStore = HKHealthStoreMock()

        let doseStore = DoseStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(WalshInsulinModel(actionDuration: .hours(4))),
            longestEffectDuration: .hours(4),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,
            provenanceIdentifier: Bundle.main.bundleIdentifier!
        )
        
        let queryFinishedExpectation = expectation(description: "query finished")
        
        doseStore.insulinOnBoard(at: Date()) { (result) in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success(let value):
                XCTAssertEqual(0, value.value)
            }
            queryFinishedExpectation.fulfill()
        }
        waitForExpectations(timeout: 3)
    }
    
    func testPumpEventTypeDoseMigration() {
        cacheStore.managedObjectContext.performAndWait {
            let event = PumpEvent(entity: PumpEvent.entity(), insertInto: cacheStore.managedObjectContext)

            event.date = Date()
            event.duration = .minutes(30)
            event.unit = .unitsPerHour
            event.type = .tempBasal
            event.value = 0.5
            event.doseType = nil

            XCTAssertNotNil(event.dose)
            XCTAssertEqual(.tempBasal, event.dose!.type)
        }
    }

    func testDeduplication() {
        cacheStore.managedObjectContext.performAndWait {
            let bolus1 = PumpEvent(context: cacheStore.managedObjectContext)

            bolus1.date = DateFormatter.descriptionFormatter.date(from: "2018-04-30 02:12:42 +0000")
            bolus1.raw = Data(hexadecimalString: "0100a600a6001b006a0c335d12")!
            bolus1.type = PumpEventType.bolus
            bolus1.dose = DoseEntry(type: .bolus, startDate: bolus1.date!, value: 4.15, unit: .units, syncIdentifier: bolus1.raw?.hexadecimalString)

            let bolus2 = PumpEvent(context: cacheStore.managedObjectContext)

            bolus2.date = DateFormatter.descriptionFormatter.date(from: "2018-04-30 00:00:00 +0000")
            bolus2.raw = Data(hexadecimalString: "0100a600a6001b006a0c335d12")!
            bolus2.type = PumpEventType.bolus
            bolus2.dose = DoseEntry(type: .bolus, startDate: bolus2.date!, value: 0.15, unit: .units, syncIdentifier: bolus1.raw?.hexadecimalString)

            let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
            let eventsBeforeSave = try! cacheStore.managedObjectContext.fetch(request)
            XCTAssertEqual(2, eventsBeforeSave.count)

            try! cacheStore.managedObjectContext.save()

            let eventsAfterSave = try! cacheStore.managedObjectContext.fetch(request)
            XCTAssertEqual(1, eventsAfterSave.count)
        }
    }

    /// See https://github.com/LoopKit/Loop/issues/853
    func testOutOfOrderDosesSyncedToHealth() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        // 1. Create a DoseStore
        let healthStore = HKHealthStoreMock()

        let doseStore = DoseStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(WalshInsulinModel(actionDuration: .hours(4))),
            longestEffectDuration: .hours(4),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,
            provenanceIdentifier: Bundle.main.bundleIdentifier!,

            // Set the current date
            test_currentDate: f("2018-12-12 18:07:14 +0000")
        )


        // 2. Add a temp basal which has already ended. It should be saved to Health
        let pumpEvents1 = [
            NewPumpEvent(date: f("2018-12-12 17:35:58 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 2.125, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 58 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-12-12 17:35:58 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 17:35:58 +0000"), endDate: f("2018-12-12 18:05:58 +0000"), value: 2.125, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "1601fa23094c12")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 58 isLeapMonth: false )", type: .tempBasal)
        ]

        doseStore.insulinDeliveryStore.test_lastBasalEndDate = f("2018-12-12 17:35:58 +0000")

        let addPumpEvents1 = expectation(description: "add pumpEvents1")
        addPumpEvents1.expectedFulfillmentCount = 2
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)
            let sample = objects.first as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, sample.insulinDeliveryReason)
            XCTAssertNil(error)
            addPumpEvents1.fulfill()
        })
        let lastBasalEndDateSetExpectation = expectation(description: "last basal end date set")
        lastBasalEndDateSetExpectation.assertForOverFulfill = false
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            lastBasalEndDateSetExpectation.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents1.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:58 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)


        // 3. Add a bolus a little later, which started before the last temp basal ends, but wasn't written to pump history until it completed (x22 pump behavior)
        // Even though it is before lastBasalEndDate, it should be saved to HealthKit.
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:16:23 +0000")

        let pumpEvents2 = [
            NewPumpEvent(date: f("2018-12-12 18:05:14 +0000"), dose: DoseEntry(type: .bolus, startDate: f("2018-12-12 18:05:14 +0000"), endDate: f("2018-12-12 18:05:14 +0000"), value: 5.0, unit: .units), isMutable: false, raw: Data(hexadecimalString: "01323200ce052a0c12")!, title: "BolusNormalPumpEvent(length: 9, rawData: 9 bytes, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 5 second: 14 isLeapMonth: false , unabsorbedInsulinRecord: nil, amount: 5.0, programmed: 5.0, unabsorbedInsulinTotal: 0.0, type: MinimedKit.BolusNormalPumpEvent.BolusType.normal, duration: 0.0, deliveryUnitsPerMinute: 1.5)", type: .bolus)
        ]

        let addPumpEvents2 = expectation(description: "add pumpEvents2")
        addPumpEvents2.expectedFulfillmentCount = 3
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)
            let sample = objects.first as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.bolus, sample.insulinDeliveryReason)
            XCTAssertEqual(5.0, sample.quantity.doubleValue(for: .internationalUnit()))
            XCTAssertEqual(f("2018-12-12 18:05:14 +0000"), sample.startDate)
            XCTAssertNil(error)
            addPumpEvents2.fulfill()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            addPumpEvents2.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents2, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents2.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:58 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)


        // Add the next set of pump events, which haven't completed and shouldn't be saved to HealthKit
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:21:22 +0000")

        let pumpEvents3 = [
            NewPumpEvent(date: f("2018-12-12 18:16:31 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0.0, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 16 second: 31 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-12-12 18:16:31 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 18:16:31 +0000"), endDate: f("2018-12-12 18:46:31 +0000"), value: 0.0, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "1601df100a4c12")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 16 second: 31 isLeapMonth: false )", type: .tempBasal),
        ]

        let addPumpEvents3 = expectation(description: "add pumpEvents3")
        addPumpEvents3.expectedFulfillmentCount = 1
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            XCTFail()
        }
        doseStore.addPumpEvents(pumpEvents3, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents3.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:58 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
    }

    /// https://github.com/LoopKit/Loop/issues/852
    func testSplitBasalsSyncedToHealth() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        // Create a DoseStore
        let healthStore = HKHealthStoreMock()

        let doseStore = DoseStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(WalshInsulinModel(actionDuration: .hours(4))),
            longestEffectDuration: .hours(4),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,
            provenanceIdentifier: Bundle.main.bundleIdentifier!,

            // Set the current date (5 minutes later)
            test_currentDate: f("2018-11-29 11:04:27 +0000")
        )
        doseStore.pumpRecordsBasalProfileStartEvents = false

        doseStore.insulinDeliveryStore.test_lastBasalEndDate = f("2018-11-29 10:54:28 +0000")

        // Add a temp basal. It hasn't finished yet, and should not be saved to Health
        let pumpEvents1 = [
            NewPumpEvent(date: f("2018-11-29 10:59:28 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0.3, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 2 minute: 59 second: 28 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-11-29 10:59:28 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 10:59:28 +0000"), endDate: f("2018-11-29 11:29:28 +0000"), value: 0.3, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "5bffc7cace53e48e87f7cfcb")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 2 minute: 59 second: 28 isLeapMonth: false )", type: .tempBasal)
        ]

        let addPumpEvents1 = expectation(description: "add pumpEvents1")
        addPumpEvents1.expectedFulfillmentCount = 1
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents1.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 10:54:28 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
        XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), doseStore.pumpEventQueryAfterDate)

        // Add the next query of the same pump events (no new data) 5 minutes later. Expect the same result
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:09:27 +0000")

        let addPumpEvents2 = expectation(description: "add pumpEvents2")
        addPumpEvents2.expectedFulfillmentCount = 1
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            XCTFail()
        }
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents2.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 10:54:28 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
        XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), doseStore.pumpEventQueryAfterDate)

        // Add the next set of pump events, including the last temp basal change.
        // The previous, completed basal entries should be saved to Health
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:14:28 +0000")

        let pumpEvents3 = [
            NewPumpEvent(date: f("2018-11-29 11:09:27 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0.325, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 9 second: 27 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-11-29 11:09:27 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 11:09:27 +0000"), endDate: f("2018-11-29 11:39:27 +0000"), value: 0.325, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "5bffca22ce53e48e87f7d624")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 9 second: 27 isLeapMonth: false )", type: .tempBasal)
        ]

        let addPumpEvents3 = expectation(description: "add pumpEvents3")
        addPumpEvents3.expectedFulfillmentCount = 3
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(3, objects.count)
            let basal = objects[0] as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, basal.insulinDeliveryReason)
            XCTAssertEqual(f("2018-11-29 10:54:28 +0000"), basal.startDate)
            XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), basal.endDate)
            XCTAssertEqual("BasalRateSchedule 2018-11-29T10:54:28Z 2018-11-29T10:59:28Z", basal.metadata![HKMetadataKeySyncIdentifier] as! String)
            let temp1 = objects[1] as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, temp1.insulinDeliveryReason)
            XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), temp1.startDate)
            XCTAssertEqual(f("2018-11-29 11:00:00 +0000"), temp1.endDate)
            XCTAssertEqual("5bffc7cace53e48e87f7cfcb 1/2", temp1.metadata![HKMetadataKeySyncIdentifier] as! String)
            XCTAssertEqual(0.003, temp1.quantity.doubleValue(for: .internationalUnit()), accuracy: 0.01)
            let temp2 = objects[2] as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, temp2.insulinDeliveryReason)
            XCTAssertEqual(f("2018-11-29 11:00:00 +0000"), temp2.startDate)
            XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), temp2.endDate)
            XCTAssertEqual("5bffc7cace53e48e87f7cfcb 2/2", temp2.metadata![HKMetadataKeySyncIdentifier] as! String)
            XCTAssertEqual(0.047, temp2.quantity.doubleValue(for: .internationalUnit()), accuracy: 0.01)
            XCTAssertNil(error)
            addPumpEvents3.fulfill()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            addPumpEvents3.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents3, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents3.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
        XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), doseStore.pumpEventQueryAfterDate)

        // Add the next set of pump events, including the last temp basal cancel
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:19:28 +0000")

        let pumpEvents4 = [
            NewPumpEvent(date: f("2018-11-29 11:14:28 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 14 second: 28 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-11-29 11:14:28 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 11:14:28 +0000"), endDate: f("2018-11-29 11:14:28 +0000"), value: 0.0, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "5bffced1ce53e48e87f7e33b")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 14 second: 28 isLeapMonth: false )", type: .tempBasal)
        ]

        let addPumpEvents4 = expectation(description: "add pumpEvents4")
        addPumpEvents4.expectedFulfillmentCount = 3
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)
            let temp = objects[0] as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, temp.insulinDeliveryReason)
            XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), temp.startDate)
            XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), temp.endDate)
            XCTAssertEqual("5bffca22ce53e48e87f7d624", temp.metadata![HKMetadataKeySyncIdentifier] as! String)
            XCTAssertEqual(0.05, temp.quantity.doubleValue(for: .internationalUnit()), accuracy: 0.01)
            XCTAssertNil(error)
            addPumpEvents4.fulfill()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            addPumpEvents4.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents4, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents4.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), doseStore.pumpEventQueryAfterDate)
        XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
    }
}

class DoseStoreQueryAnchorTests: XCTestCase {
    
    var rawValue: DoseStore.QueryAnchor.RawValue = [
        "modificationCounter": Int64(123),
        "scheduledBasalStartDate": dateFormatter.date(from: "2022-01-05T11:14:28Z")!
    ]
    
    func testInitializerDefault() {
        let queryAnchor = DoseStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.modificationCounter, 0)
        XCTAssertNil(queryAnchor.scheduledBasalStartDate)
    }
    
    func testInitializerRawValue() {
        let queryAnchor = DoseStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.modificationCounter, 123)
        XCTAssertEqual(queryAnchor?.scheduledBasalStartDate, Self.dateFormatter.date(from: "2022-01-05T11:14:28Z")!)
    }
    
    func testInitializerRawValueMissingModificationCounter() {
        rawValue["modificationCounter"] = nil
        rawValue["scheduledBasalStartDate"] = Self.dateFormatter.date(from: "2022-01-05T11:14:28Z")!
        XCTAssertNil(DoseStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testInitializerRawValueInvalidModificationCounter() {
        rawValue["modificationCounter"] = "123"
        XCTAssertNil(DoseStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testRawValueWithDefault() {
        let rawValue = DoseStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(0))
    }
    
    func testRawValueWithNonDefault() {
        var queryAnchor = DoseStore.QueryAnchor()
        queryAnchor.modificationCounter = 123
        queryAnchor.scheduledBasalStartDate = Self.dateFormatter.date(from: "2022-01-05T11:14:28Z")!
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 2)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(123))
        XCTAssertEqual(rawValue["scheduledBasalStartDate"] as? Date, Self.dateFormatter.date(from: "2022-01-05T11:14:28Z")!)
    }

    private static let dateFormatter = ISO8601DateFormatter()
    
}

class DoseStoreQueryTests: PersistenceControllerTestCase {
    
    let insulinModel = WalshInsulinModel(actionDuration: .hours(4))
    let basalProfile = BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]])
    let insulinSensitivitySchedule = InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]])
    
    var doseStore: DoseStore!
    var completion: XCTestExpectation!
    var queryAnchor: DoseStore.QueryAnchor!
    var limit: Int!
    
    override func setUp() {
        super.setUp()
        
        doseStore = DoseStore(healthStore: HKHealthStoreMock(),
                              cacheStore: cacheStore,
                              observationEnabled: false,
                              insulinModelProvider: StaticInsulinModelProvider(insulinModel),
                              longestEffectDuration: insulinModel.effectDuration,
                              basalProfile: basalProfile,
                              insulinSensitivitySchedule: insulinSensitivitySchedule,
                              provenanceIdentifier: Bundle.main.bundleIdentifier!)
        completion = expectation(description: "Completion")
        queryAnchor = DoseStore.QueryAnchor()
        limit = Int.max
    }
    
    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        doseStore = nil
        
        super.tearDown()
    }

    func testPumpEmptyWithDefaultQueryAnchor() {
        doseStore.executePumpQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpEmptyWithMissingQueryAnchor() {
        queryAnchor = nil
        
        doseStore.executePumpQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.modificationCounter = 1
        
        doseStore.executePumpQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 1)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpDataWithUnusedQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addPumpData(withSyncIdentifiers: syncIdentifiers)

        doseStore.executePumpQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 3)
                for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                    XCTAssertEqual(data[index].syncIdentifier, syncIdentifier)
                }
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpDataWithStaleQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addPumpData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.modificationCounter = 2
        
        doseStore.executePumpQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 1)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[2])
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpDataWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addPumpData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.modificationCounter = 3
        
        doseStore.executePumpQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpDataWithLimitCoveredByData() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addPumpData(withSyncIdentifiers: syncIdentifiers)

        limit = 2
        
        doseStore.executePumpQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 2)
                XCTAssertEqual(data.count, 2)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(data[1].syncIdentifier, syncIdentifiers[1])
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    private func addPumpData(withSyncIdentifiers syncIdentifiers: [String]) {
        cacheStore.managedObjectContext.performAndWait {
            for syncIdentifier in syncIdentifiers {
                let pumpEvent = PumpEvent(context: self.cacheStore.managedObjectContext)
                pumpEvent.date = Date()
                pumpEvent.type = PumpEventType.allCases.randomElement()!
                switch pumpEvent.type {
                case .alarm:
                    pumpEvent.alarmType = .occlusion
                case .basal:
                    pumpEvent.dose = DoseEntry(type: .basal, startDate: Date(), value: 0.75, unit: .unitsPerHour)
                case .bolus:
                    pumpEvent.dose = DoseEntry(type: .bolus, startDate: Date(), value: 1.25, unit: .units)
                case .resume:
                    pumpEvent.dose = DoseEntry(resumeDate: Date())
                case .suspend:
                    pumpEvent.dose = DoseEntry(suspendDate: Date())
                case .tempBasal:
                    pumpEvent.dose = DoseEntry(type: .tempBasal, startDate: Date(), value: 0, unit: .units)
                default:
                    break
                }
                pumpEvent.raw = Data(hexadecimalString: syncIdentifier)
                
                self.cacheStore.save()
            }
        }
    }
    
    private func generateSyncIdentifier() -> String {
        return UUID().data.hexadecimalString
    }
    
}

class DoseStoreQueryAndMergeTests: PersistenceControllerTestCase {

    let insulinModel = WalshInsulinModel(actionDuration: .hours(4))
    let basalProfile = BasalRateSchedule(rawValue: ["timeZone": 0, "items": [["value": 0.5, "startTime": 0.0], ["value": 0.7, "startTime": 3600]]])
    let insulinSensitivitySchedule = InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": 0, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 3600.0]]])

    var doseStore: DoseStore!
    var completion: XCTestExpectation!
    var queryAnchor: DoseStore.QueryAnchor!
    var limit: Int!

    override func setUp() {
        super.setUp()

        doseStore = DoseStore(healthStore: HKHealthStoreMock(),
                              cacheStore: cacheStore,
                              observationEnabled: false,
                              insulinModelProvider: StaticInsulinModelProvider(insulinModel),
                              longestEffectDuration: insulinModel.effectDuration,
                              basalProfile: basalProfile,
                              insulinSensitivitySchedule: insulinSensitivitySchedule,
                              provenanceIdentifier: Bundle.main.bundleIdentifier!)
        completion = expectation(description: "Completion")
        queryAnchor = DoseStore.QueryAnchor()
        limit = Int.max
    }

    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        doseStore = nil

        super.tearDown()
    }

    func testInitialResume() {
        doseStore.insulinDeliveryStore.test_currentDate = f("2022-01-10T00:35:00Z")

        let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .resume,
                                                       startDate: f("2022-01-10T00:10:00Z"),
                                                       value: 0,
                                                       unit: .units,
                                                       syncIdentifier: "e2bae2b6b317416a9816edab137c9278"))]
        doseStore.addPumpEvents(pumpEvents, lastReconciliation: f("2022-01-10T00:30:00Z")) { error in
            XCTAssertNil(error)
            self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                switch result {
                case .failure(let error):
                    XCTFail("Unexpected failure: \(error)")
                case .success(_, let data):
                    XCTAssertEqual(data.count, 1)

                    XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:10:00Z"))
                    XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:10:00Z"))
                    XCTAssertEqual(data[0].dose?.type, .resume)
                    XCTAssertFalse(data[0].mutable)
                    XCTAssertEqual(data[0].syncIdentifier, "e2bae2b6b317416a9816edab137c9278")
                }
                self.completion.fulfill()
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testTempBasalMutable() {
        doseStore.insulinDeliveryStore.test_currentDate = f("2022-01-10T00:35:00Z")

        let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                       startDate: f("2022-01-10T00:15:00Z"),
                                                       endDate: f("2022-01-10T00:45:00Z"),
                                                       value: 4.5,
                                                       unit: .unitsPerHour,
                                                       deliveredUnits: nil,
                                                       syncIdentifier: "e2bae2b6b317416a9816edab137c9278"),
                                       isMutable: true)]
        doseStore.addPumpEvents(pumpEvents, lastReconciliation: f("2022-01-10T00:30:00Z")) { error in
            XCTAssertNil(error)
            self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                switch result {
                case .failure(let error):
                    XCTFail("Unexpected failure: \(error)")
                case .success(_, let data):
                    XCTAssertEqual(data.count, 1)

                    XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:15:00Z"))
                    XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:45:00Z"))
                    XCTAssertEqual(data[0].dose?.type, .tempBasal)
                    XCTAssertEqual(data[0].dose?.unitsPerHour, 4.5)
                    XCTAssertNil(data[0].dose?.duringSuspend)
                    XCTAssertNil(data[0].dose?.scheduledBasalRate)
                    XCTAssertTrue(data[0].mutable)
                    XCTAssertEqual(data[0].syncIdentifier, "e2bae2b6b317416a9816edab137c9278")
                }
                self.completion.fulfill()
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testTempBasalImmutable() {
        doseStore.insulinDeliveryStore.test_currentDate = f("2022-01-10T00:35:00Z")

        let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                       startDate: f("2022-01-10T00:15:00Z"),
                                                       endDate: f("2022-01-10T00:30:00Z"),
                                                       value: 4.5,
                                                       unit: .unitsPerHour,
                                                       deliveredUnits: nil,
                                                       syncIdentifier: "e2bae2b6b317416a9816edab137c9278"))]
        doseStore.addPumpEvents(pumpEvents, lastReconciliation: f("2022-01-10T00:30:00Z")) { error in
            XCTAssertNil(error)
            self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                switch result {
                case .failure(let error):
                    XCTFail("Unexpected failure: \(error)")
                case .success(_, let data):
                    XCTAssertEqual(data.count, 4)

                    XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-09T00:35:00Z"))
                    XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-09T01:00:00Z"))
                    XCTAssertEqual(data[0].dose?.type, .basal)
                    XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                    XCTAssertFalse(data[0].mutable)

                    XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-09T01:00:00Z"))
                    XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T00:00:00Z"))
                    XCTAssertEqual(data[1].dose?.type, .basal)
                    XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                    XCTAssertFalse(data[1].mutable)

                    XCTAssertEqual(data[2].dose?.startDate, self.f("2022-01-10T00:00:00Z"))
                    XCTAssertEqual(data[2].dose?.endDate, self.f("2022-01-10T00:15:00Z"))
                    XCTAssertEqual(data[2].dose?.type, .basal)
                    XCTAssertEqual(data[2].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                    XCTAssertFalse(data[2].mutable)

                    XCTAssertEqual(data[3].dose?.startDate, self.f("2022-01-10T00:15:00Z"))
                    XCTAssertEqual(data[3].dose?.endDate, self.f("2022-01-10T00:30:00Z"))
                    XCTAssertEqual(data[3].dose?.type, .tempBasal)
                    XCTAssertEqual(data[3].dose?.unitsPerHour, 4.5)
                    XCTAssertNil(data[3].dose?.duringSuspend)
                    XCTAssertEqual(data[3].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                    XCTAssertFalse(data[3].mutable)
                    XCTAssertEqual(data[3].syncIdentifier, "e2bae2b6b317416a9816edab137c9278")
                }
                self.completion.fulfill()
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testTempBasalImmutableWithPumpRecordsBasal() {
        doseStore.pumpRecordsBasalProfileStartEvents = true
        doseStore.insulinDeliveryStore.test_currentDate = f("2022-01-10T00:35:00Z")

        let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                       startDate: f("2022-01-10T00:15:00Z"),
                                                       endDate: f("2022-01-10T00:30:00Z"),
                                                       value: 4.5,
                                                       unit: .unitsPerHour,
                                                       deliveredUnits: nil,
                                                       syncIdentifier: "e2bae2b6b317416a9816edab137c9278"))]
        doseStore.addPumpEvents(pumpEvents, lastReconciliation: f("2022-01-10T00:30:00Z")) { error in
            XCTAssertNil(error)
            self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                switch result {
                case .failure(let error):
                    XCTFail("Unexpected failure: \(error)")
                case .success(_, let data):
                    XCTAssertEqual(data.count, 1)

                    XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:15:00Z"))
                    XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:30:00Z"))
                    XCTAssertEqual(data[0].dose?.type, .tempBasal)
                    XCTAssertEqual(data[0].dose?.unitsPerHour, 4.5)
                    XCTAssertNil(data[0].dose?.duringSuspend)
                    XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                    XCTAssertFalse(data[0].mutable)
                    XCTAssertEqual(data[0].syncIdentifier, "e2bae2b6b317416a9816edab137c9278")
                }
                self.completion.fulfill()
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testNextTempBasalMutable() {
        populateInitialEvents {
            self.doseStore.insulinDeliveryStore.test_currentDate = self.f("2022-01-10T01:10:00Z")

            let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T00:35:00Z"),
                                                           endDate: self.f("2022-01-10T01:05:00Z"),
                                                           value: 3.5,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "4c6f0e0610cf4e678dbf4a068e018bf2"),
                                          isMutable: true)]
            self.doseStore.addPumpEvents(pumpEvents, lastReconciliation: self.f("2022-01-10T01:10:00Z")) { error in
                XCTAssertNil(error)
                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                    switch result {
                    case .failure(let error):
                        XCTFail("Unexpected failure: \(error)")
                    case .success(_, let data):
                        XCTAssertEqual(data.count, 1)

                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[0].dose?.type, .tempBasal)
                        XCTAssertEqual(data[0].dose?.unitsPerHour, 3.5)
                        XCTAssertNil(data[0].dose?.duringSuspend)
                        XCTAssertNil(data[0].dose?.scheduledBasalRate)
                        XCTAssertTrue(data[0].mutable)
                        XCTAssertEqual(data[0].syncIdentifier, "4c6f0e0610cf4e678dbf4a068e018bf2")
                    }
                    self.completion.fulfill()
                }
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testNextTempBasalImmutableSpanningMultipleScheduledBasals() {
        populateInitialEvents {
            self.doseStore.insulinDeliveryStore.test_currentDate = self.f("2022-01-10T01:10:00Z")

            let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T00:35:00Z"),
                                                           endDate: self.f("2022-01-10T01:05:00Z"),
                                                           value: 3.5,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "4c6f0e0610cf4e678dbf4a068e018bf2"))]
            self.doseStore.addPumpEvents(pumpEvents, lastReconciliation: self.f("2022-01-10T01:10:00Z")) { error in
                XCTAssertNil(error)
                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                    switch result {
                    case .failure(let error):
                        XCTFail("Unexpected failure: \(error)")
                    case .success(_, let data):
                        XCTAssertEqual(data.count, 3)

                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:30:00Z"))
                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[0].dose?.type, .basal)
                        XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[0].mutable)

                        XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T01:00:00Z"))
                        XCTAssertEqual(data[1].dose?.type, .tempBasal)
                        XCTAssertEqual(data[1].dose?.unitsPerHour, 3.5)
                        XCTAssertNil(data[1].dose?.duringSuspend)
                        XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[1].mutable)
                        XCTAssertEqual(data[1].syncIdentifier, "4c6f0e0610cf4e678dbf4a068e018bf2 1/2")

                        XCTAssertEqual(data[2].dose?.startDate, self.f("2022-01-10T01:00:00Z"))
                        XCTAssertEqual(data[2].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[2].dose?.type, .tempBasal)
                        XCTAssertEqual(data[2].dose?.unitsPerHour, 3.5)
                        XCTAssertNil(data[2].dose?.duringSuspend)
                        XCTAssertEqual(data[2].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                        XCTAssertFalse(data[2].mutable)
                        XCTAssertEqual(data[2].syncIdentifier, "4c6f0e0610cf4e678dbf4a068e018bf2 2/2")
                    }
                    self.completion.fulfill()
                }
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testBolusMutable() {
        populateInitialEvents {
            self.doseStore.insulinDeliveryStore.test_currentDate = self.f("2022-01-10T00:41:00Z")

            let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .bolus,
                                                           startDate: self.f("2022-01-10T00:40:00Z"),
                                                           endDate: self.f("2022-01-10T00:42:00Z"),
                                                           value: 3.5,
                                                           unit: .units,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "484092b636f141c5beb025b546fcaa0f"),
                                           isMutable: true)]
            self.doseStore.addPumpEvents(pumpEvents, lastReconciliation: self.f("2022-01-10T00:41:00Z")) { error in
                XCTAssertNil(error)
                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                    switch result {
                    case .failure(let error):
                        XCTFail("Unexpected failure: \(error)")
                    case .success(_, let data):
                        XCTAssertEqual(data.count, 1)

                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:40:00Z"))
                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:42:00Z"))
                        XCTAssertEqual(data[0].dose?.type, .bolus)
                        XCTAssertEqual(data[0].dose?.programmedUnits, 3.5)
                        XCTAssertTrue(data[0].mutable)
                        XCTAssertEqual(data[0].syncIdentifier, "484092b636f141c5beb025b546fcaa0f")
                    }
                    self.completion.fulfill()
                }
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testBolusImmutableInterrupted() {
        populateInitialEvents {
            self.doseStore.insulinDeliveryStore.test_currentDate = self.f("2022-01-10T00:41:00Z")

            let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .bolus,
                                                           startDate: self.f("2022-01-10T00:40:00Z"),
                                                           endDate: self.f("2022-01-10T00:41:00Z"),
                                                           value: 3.5,
                                                           unit: .units,
                                                           deliveredUnits: 2.0,
                                                           syncIdentifier: "484092b636f141c5beb025b546fcaa0f"))]
            self.doseStore.addPumpEvents(pumpEvents, lastReconciliation: self.f("2022-01-10T00:42:00Z")) { error in
                XCTAssertNil(error)
                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                    switch result {
                    case .failure(let error):
                        XCTFail("Unexpected failure: \(error)")
                    case .success(_, let data):
                        XCTAssertEqual(data.count, 1)

                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:40:00Z"))
                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:41:00Z"))
                        XCTAssertEqual(data[0].dose?.type, .bolus)
                        XCTAssertEqual(data[0].dose?.programmedUnits, 3.5)
                        XCTAssertEqual(data[0].dose?.deliveredUnits, 2.0)
                        XCTAssertFalse(data[0].mutable)
                        XCTAssertEqual(data[0].syncIdentifier, "484092b636f141c5beb025b546fcaa0f")
                    }
                    self.completion.fulfill()
                }
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testSuspendResumeSpanningMultipleScheduledBasals() {
        populateInitialEvents {
            self.doseStore.insulinDeliveryStore.test_currentDate = self.f("2022-01-10T01:10:00Z")

            let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .suspend,
                                                           startDate: self.f("2022-01-10T00:35:00Z"),
                                                           value: 0,
                                                           unit: .units,
                                                           syncIdentifier: "07de19a9c35c49e3aa1590e42b818eb0")),
                              NewPumpEvent(dose: DoseEntry(type: .resume,
                                                           startDate: self.f("2022-01-10T01:05:00Z"),
                                                           value: 0,
                                                           unit: .units,
                                                           syncIdentifier: "3b6aceda2cf141f59cbee9d4e07eb7ee")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T01:05:00Z"),
                                                           endDate: self.f("2022-01-10T01:10:00Z"),
                                                           value: 2.5,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "4747359c857f4b04810df17c781d9bcc"))]
            self.doseStore.addPumpEvents(pumpEvents, lastReconciliation: self.f("2022-01-10T01:10:00Z")) { error in
                XCTAssertNil(error)
                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                    switch result {
                    case .failure(let error):
                        XCTFail("Unexpected failure: \(error)")
                    case .success(_, let data):
                        XCTAssertEqual(data.count, 6)

                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:30:00Z"))
                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[0].dose?.type, .basal)
                        XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[0].mutable)

                        XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[1].dose?.type, .suspend)
                        XCTAssertNil(data[1].dose?.scheduledBasalRate)
                        XCTAssertFalse(data[1].mutable)
                        XCTAssertEqual(data[1].syncIdentifier, "07de19a9c35c49e3aa1590e42b818eb0")

                        XCTAssertEqual(data[2].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[2].dose?.endDate, self.f("2022-01-10T01:00:00Z"))
                        XCTAssertEqual(data[2].dose?.type, .tempBasal)
                        XCTAssertEqual(data[2].dose?.unitsPerHour, 0)
                        XCTAssertEqual(data[2].dose?.duringSuspend, true)
                        XCTAssertEqual(data[2].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[2].mutable)

                        XCTAssertEqual(data[3].dose?.startDate, self.f("2022-01-10T01:00:00Z"))
                        XCTAssertEqual(data[3].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[3].dose?.type, .tempBasal)
                        XCTAssertEqual(data[3].dose?.unitsPerHour, 0)
                        XCTAssertEqual(data[3].dose?.duringSuspend, true)
                        XCTAssertEqual(data[3].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                        XCTAssertFalse(data[3].mutable)

                        XCTAssertEqual(data[4].dose?.startDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[4].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[4].dose?.type, .resume)
                        XCTAssertNil(data[4].dose?.scheduledBasalRate)
                        XCTAssertFalse(data[4].mutable)
                        XCTAssertEqual(data[4].syncIdentifier, "3b6aceda2cf141f59cbee9d4e07eb7ee")

                        XCTAssertEqual(data[5].dose?.startDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[5].dose?.endDate, self.f("2022-01-10T01:10:00Z"))
                        XCTAssertEqual(data[5].dose?.type, .tempBasal)
                        XCTAssertEqual(data[5].dose?.unitsPerHour, 2.5)
                        XCTAssertNil(data[5].dose?.duringSuspend)
                        XCTAssertEqual(data[5].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                        XCTAssertFalse(data[5].mutable)
                        XCTAssertEqual(data[5].syncIdentifier, "4747359c857f4b04810df17c781d9bcc")
                    }
                    self.completion.fulfill()
                }
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testSuspendResumeSpanningMultipleScheduledBasalsWithPumpRecordsBasal() {
        populateInitialEvents {
            self.doseStore.pumpRecordsBasalProfileStartEvents = true
            self.doseStore.insulinDeliveryStore.test_currentDate = self.f("2022-01-10T01:10:00Z")

            let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .suspend,
                                                           startDate: self.f("2022-01-10T00:35:00Z"),
                                                           value: 0,
                                                           unit: .units,
                                                           syncIdentifier: "07de19a9c35c49e3aa1590e42b818eb0")),
                              NewPumpEvent(dose: DoseEntry(type: .resume,
                                                           startDate: self.f("2022-01-10T01:05:00Z"),
                                                           value: 0,
                                                           unit: .units,
                                                           syncIdentifier: "3b6aceda2cf141f59cbee9d4e07eb7ee")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T01:05:00Z"),
                                                           endDate: self.f("2022-01-10T01:10:00Z"),
                                                           value: 2.5,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "4747359c857f4b04810df17c781d9bcc"))]
            self.doseStore.addPumpEvents(pumpEvents, lastReconciliation: self.f("2022-01-10T01:10:00Z")) { error in
                XCTAssertNil(error)
                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                    switch result {
                    case .failure(let error):
                        XCTFail("Unexpected failure: \(error)")
                    case .success(_, let data):
                        XCTAssertEqual(data.count, 5)

                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[0].dose?.type, .suspend)
                        XCTAssertNil(data[0].dose?.scheduledBasalRate)
                        XCTAssertFalse(data[0].mutable)
                        XCTAssertEqual(data[0].syncIdentifier, "07de19a9c35c49e3aa1590e42b818eb0")

                        XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T01:00:00Z"))
                        XCTAssertEqual(data[1].dose?.type, .tempBasal)
                        XCTAssertEqual(data[1].dose?.unitsPerHour, 0)
                        XCTAssertEqual(data[1].dose?.duringSuspend, true)
                        XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[1].mutable)

                        XCTAssertEqual(data[2].dose?.startDate, self.f("2022-01-10T01:00:00Z"))
                        XCTAssertEqual(data[2].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[2].dose?.type, .tempBasal)
                        XCTAssertEqual(data[2].dose?.unitsPerHour, 0)
                        XCTAssertEqual(data[2].dose?.duringSuspend, true)
                        XCTAssertEqual(data[2].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                        XCTAssertFalse(data[2].mutable)

                        XCTAssertEqual(data[3].dose?.startDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[3].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[3].dose?.type, .resume)
                        XCTAssertNil(data[3].dose?.scheduledBasalRate)
                        XCTAssertFalse(data[3].mutable)
                        XCTAssertEqual(data[3].syncIdentifier, "3b6aceda2cf141f59cbee9d4e07eb7ee")

                        XCTAssertEqual(data[4].dose?.startDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[4].dose?.endDate, self.f("2022-01-10T01:10:00Z"))
                        XCTAssertEqual(data[4].dose?.type, .tempBasal)
                        XCTAssertEqual(data[4].dose?.unitsPerHour, 2.5)
                        XCTAssertNil(data[4].dose?.duringSuspend)
                        XCTAssertEqual(data[4].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                        XCTAssertFalse(data[4].mutable)
                        XCTAssertEqual(data[4].syncIdentifier, "4747359c857f4b04810df17c781d9bcc")
                    }
                    self.completion.fulfill()
                }
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testAll() {
        populateInitialEvents {
            self.doseStore.insulinDeliveryStore.test_currentDate = self.f("2022-01-10T01:10:00Z")

            let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .suspend,
                                                           startDate: self.f("2022-01-10T00:35:00Z"),
                                                           value: 0,
                                                           unit: .units,
                                                           syncIdentifier: "07de19a9c35c49e3aa1590e42b818eb0")),
                              NewPumpEvent(date: self.f("2022-01-10T00:35:00Z"),
                                           type: .alarm,
                                           alarmType: .occlusion,
                                           syncIdentifier: "97c199328ece438a8098289ff1abf3c8"),
                              NewPumpEvent(date: self.f("2022-01-10T00:40:00Z"),
                                           type: .alarmClear,
                                           syncIdentifier: "d926c8a0f24d47d483254d602ae12342"),
                              NewPumpEvent(date: self.f("2022-01-10T00:45:00Z"),
                                           type: .rewind,
                                           syncIdentifier: "aa996aa7b0674155af7f2cdb675c2357"),
                              NewPumpEvent(date: self.f("2022-01-10T00:47:00Z"),
                                           type: .prime,
                                           syncIdentifier: "b39fe47823f64bdf8cb3f511be5033f5"),
                              NewPumpEvent(dose: DoseEntry(type: .resume,
                                                           startDate: self.f("2022-01-10T01:05:00Z"),
                                                           value: 0,
                                                           unit: .units,
                                                           syncIdentifier: "3b6aceda2cf141f59cbee9d4e07eb7ee")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T01:05:00Z"),
                                                           endDate: self.f("2022-01-10T01:15:00Z"),
                                                           value: 2.5,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "4747359c857f4b04810df17c781d9bcc")),
                              NewPumpEvent(dose: DoseEntry(type: .bolus,
                                                           startDate: self.f("2022-01-10T01:10:00Z"),
                                                           endDate: self.f("2022-01-10T01:11:00Z"),
                                                           value: 2.5,
                                                           unit: .units,
                                                           deliveredUnits: 1.5,
                                                           syncIdentifier: "caab9921ec2a437285f61400ca1cbc0a")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T01:15:00Z"),
                                                           endDate: self.f("2022-01-10T01:45:00Z"),
                                                           value: 0.5,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "34528b71a99f43c1a500c080b9136ad7"),
                                           isMutable: true),
                              NewPumpEvent(dose: DoseEntry(type: .bolus,
                                                           startDate: self.f("2022-01-10T01:20:00Z"),
                                                           endDate: self.f("2022-01-10T01:22:00Z"),
                                                           value: 0.75,
                                                           unit: .units,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "b05e892486d140348e961c63633c3564"),
                                          isMutable: true)]
            self.doseStore.addPumpEvents(pumpEvents, lastReconciliation: self.f("2022-01-10T01:10:00Z")) { error in
                XCTAssertNil(error)
                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                    switch result {
                    case .failure(let error):
                        XCTFail("Unexpected failure: \(error)")
                    case .success(_, let data):
                        XCTAssertEqual(data.count, 13)

                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:30:00Z"))
                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[0].dose?.type, .basal)
                        XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[0].mutable)

                        XCTAssertEqual(data[1].date, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[1].type, .alarm)
                        XCTAssertEqual(data[1].alarmType, .occlusion)
                        XCTAssertFalse(data[1].mutable)
                        XCTAssertEqual(data[1].syncIdentifier, "97c199328ece438a8098289ff1abf3c8")

                        XCTAssertEqual(data[2].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[2].dose?.endDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[2].dose?.type, .suspend)
                        XCTAssertNil(data[2].dose?.scheduledBasalRate)
                        XCTAssertFalse(data[2].mutable)
                        XCTAssertEqual(data[2].syncIdentifier, "07de19a9c35c49e3aa1590e42b818eb0")

                        XCTAssertEqual(data[3].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[3].dose?.endDate, self.f("2022-01-10T01:00:00Z"))
                        XCTAssertEqual(data[3].dose?.type, .tempBasal)
                        XCTAssertEqual(data[3].dose?.unitsPerHour, 0)
                        XCTAssertEqual(data[3].dose?.duringSuspend, true)
                        XCTAssertEqual(data[3].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[3].mutable)
                        XCTAssertEqual(data[3].syncIdentifier, "07de19a9c35c49e3aa1590e42b818eb0 1/2")

                        XCTAssertEqual(data[4].date, self.f("2022-01-10T00:40:00Z"))
                        XCTAssertEqual(data[4].type, .alarmClear)
                        XCTAssertFalse(data[4].mutable)
                        XCTAssertEqual(data[4].syncIdentifier, "d926c8a0f24d47d483254d602ae12342")

                        XCTAssertEqual(data[5].date, self.f("2022-01-10T00:45:00Z"))
                        XCTAssertEqual(data[5].type, .rewind)
                        XCTAssertFalse(data[5].mutable)
                        XCTAssertEqual(data[5].syncIdentifier, "aa996aa7b0674155af7f2cdb675c2357")

                        XCTAssertEqual(data[6].date, self.f("2022-01-10T00:47:00Z"))
                        XCTAssertEqual(data[6].type, .prime)
                        XCTAssertFalse(data[6].mutable)
                        XCTAssertEqual(data[6].syncIdentifier, "b39fe47823f64bdf8cb3f511be5033f5")

                        XCTAssertEqual(data[7].dose?.startDate, self.f("2022-01-10T01:00:00Z"))
                        XCTAssertEqual(data[7].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[7].dose?.type, .tempBasal)
                        XCTAssertEqual(data[7].dose?.unitsPerHour, 0)
                        XCTAssertEqual(data[7].dose?.duringSuspend, true)
                        XCTAssertEqual(data[7].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                        XCTAssertFalse(data[7].mutable)
                        XCTAssertEqual(data[7].syncIdentifier, "07de19a9c35c49e3aa1590e42b818eb0 2/2")

                        XCTAssertEqual(data[8].dose?.startDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[8].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[8].dose?.type, .resume)
                        XCTAssertNil(data[8].dose?.scheduledBasalRate)
                        XCTAssertFalse(data[8].mutable)
                        XCTAssertEqual(data[8].syncIdentifier, "3b6aceda2cf141f59cbee9d4e07eb7ee")

                        XCTAssertEqual(data[9].dose?.startDate, self.f("2022-01-10T01:05:00Z"))
                        XCTAssertEqual(data[9].dose?.endDate, self.f("2022-01-10T01:15:00Z"))
                        XCTAssertEqual(data[9].dose?.type, .tempBasal)
                        XCTAssertEqual(data[9].dose?.unitsPerHour, 2.5)
                        XCTAssertNil(data[9].dose?.duringSuspend)
                        XCTAssertNil(data[9].dose?.scheduledBasalRate)
                        XCTAssertFalse(data[9].mutable)
                        XCTAssertEqual(data[9].syncIdentifier, "4747359c857f4b04810df17c781d9bcc")

                        XCTAssertEqual(data[10].dose?.startDate, self.f("2022-01-10T01:10:00Z"))
                        XCTAssertEqual(data[10].dose?.endDate, self.f("2022-01-10T01:11:00Z"))
                        XCTAssertEqual(data[10].dose?.type, .bolus)
                        XCTAssertEqual(data[10].dose?.programmedUnits, 2.5)
                        XCTAssertEqual(data[10].dose?.deliveredUnits, 1.5)
                        XCTAssertFalse(data[10].mutable)
                        XCTAssertEqual(data[10].syncIdentifier, "caab9921ec2a437285f61400ca1cbc0a")

                        XCTAssertEqual(data[11].dose?.startDate, self.f("2022-01-10T01:15:00Z"))
                        XCTAssertEqual(data[11].dose?.endDate, self.f("2022-01-10T01:45:00Z"))
                        XCTAssertEqual(data[11].dose?.type, .tempBasal)
                        XCTAssertEqual(data[11].dose?.unitsPerHour, 0.5)
                        XCTAssertNil(data[11].dose?.duringSuspend)
                        XCTAssertNil(data[11].dose?.scheduledBasalRate)
                        XCTAssertTrue(data[11].mutable)
                        XCTAssertEqual(data[11].syncIdentifier, "34528b71a99f43c1a500c080b9136ad7")

                        XCTAssertEqual(data[12].dose?.startDate, self.f("2022-01-10T01:20:00Z"))
                        XCTAssertEqual(data[12].dose?.endDate, self.f("2022-01-10T01:22:00Z"))
                        XCTAssertEqual(data[12].dose?.type, .bolus)
                        XCTAssertEqual(data[12].dose?.programmedUnits, 0.75)
                        XCTAssertTrue(data[12].mutable)
                        XCTAssertEqual(data[12].syncIdentifier, "b05e892486d140348e961c63633c3564")
                    }
                    self.completion.fulfill()
                }
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testPaging() {
        populateInitialEvents {
            self.doseStore.insulinDeliveryStore.test_currentDate = self.f("2022-01-10T01:25:00Z")
            self.limit = 2

            let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                            startDate: self.f("2022-01-10T00:30:00Z"),
                                                            endDate: self.f("2022-01-10T00:35:00Z"),
                                                            value: 2.5,
                                                            unit: .unitsPerHour,
                                                            deliveredUnits: nil,
                                                            syncIdentifier: "d86434bba46f499ea23c25e98c66687e")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T00:40:00Z"),
                                                           endDate: self.f("2022-01-10T00:45:00Z"),
                                                           value: 2.0,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "5c0c229d093f40869e8685cb5eb53c15")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T00:55:00Z"),
                                                           endDate: self.f("2022-01-10T01:05:00Z"),
                                                           value: 1.5,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "740f67b2c29b4a64a918046a8b09c5f3")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T01:15:00Z"),
                                                           endDate: self.f("2022-01-10T01:20:00Z"),
                                                           value: 1.0,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "1e96187ea69643b2a69e94d3c539fd64"))]
            self.doseStore.addPumpEvents(pumpEvents, lastReconciliation: self.f("2022-01-10T01:25:00Z")) { error in
                XCTAssertNil(error)
                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                    switch result {
                    case .failure(let error):
                        XCTFail("Unexpected failure: \(error)")
                    case .success(let queryAnchor, let data):
                        XCTAssertEqual(data.count, 2)

                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:30:00Z"))
                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[0].dose?.type, .tempBasal)
                        XCTAssertEqual(data[0].dose?.unitsPerHour, 2.5)
                        XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[0].mutable)
                        XCTAssertEqual(data[0].syncIdentifier, "d86434bba46f499ea23c25e98c66687e")

                        XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T00:40:00Z"))
                        XCTAssertEqual(data[1].dose?.type, .basal)
                        XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[1].mutable)

                        self.queryAnchor = queryAnchor

                        self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                            switch result {
                            case .failure(let error):
                                XCTFail("Unexpected failure: \(error)")
                            case .success(let queryAnchor, let data):
                                XCTAssertEqual(data.count, 2)

                                XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:40:00Z"))
                                XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:45:00Z"))
                                XCTAssertEqual(data[0].dose?.type, .tempBasal)
                                XCTAssertEqual(data[0].dose?.unitsPerHour, 2.0)
                                XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                                XCTAssertFalse(data[0].mutable)
                                XCTAssertEqual(data[0].syncIdentifier, "5c0c229d093f40869e8685cb5eb53c15")

                                XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T00:45:00Z"))
                                XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T00:55:00Z"))
                                XCTAssertEqual(data[1].dose?.type, .basal)
                                XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                                XCTAssertFalse(data[1].mutable)

                                self.queryAnchor = queryAnchor

                                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                                    switch result {
                                    case .failure(let error):
                                        XCTFail("Unexpected failure: \(error)")
                                    case .success(let queryAnchor, let data):
                                        XCTAssertEqual(data.count, 2)

                                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:55:00Z"))
                                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T01:00:00Z"))
                                        XCTAssertEqual(data[0].dose?.type, .tempBasal)
                                        XCTAssertEqual(data[0].dose?.unitsPerHour, 1.5)
                                        XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                                        XCTAssertFalse(data[0].mutable)
                                        XCTAssertEqual(data[0].syncIdentifier, "740f67b2c29b4a64a918046a8b09c5f3 1/2")

                                        XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T01:00:00Z"))
                                        XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                                        XCTAssertEqual(data[1].dose?.type, .tempBasal)
                                        XCTAssertEqual(data[1].dose?.unitsPerHour, 1.5)
                                        XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                                        XCTAssertFalse(data[1].mutable)
                                        XCTAssertEqual(data[1].syncIdentifier, "740f67b2c29b4a64a918046a8b09c5f3 2/2")

                                        self.queryAnchor = queryAnchor

                                        self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                                            switch result {
                                            case .failure(let error):
                                                XCTFail("Unexpected failure: \(error)")
                                            case .success(let queryAnchor, let data):
                                                XCTAssertEqual(data.count, 2)

                                                XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T01:05:00Z"))
                                                XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T01:15:00Z"))
                                                XCTAssertEqual(data[0].dose?.type, .basal)
                                                XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                                                XCTAssertFalse(data[0].mutable)

                                                XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T01:15:00Z"))
                                                XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T01:20:00Z"))
                                                XCTAssertEqual(data[1].dose?.type, .tempBasal)
                                                XCTAssertEqual(data[1].dose?.unitsPerHour, 1.0)
                                                XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                                                XCTAssertFalse(data[1].mutable)
                                                XCTAssertEqual(data[1].syncIdentifier, "1e96187ea69643b2a69e94d3c539fd64")

                                                self.queryAnchor = queryAnchor

                                                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                                                    switch result {
                                                    case .failure(let error):
                                                        XCTFail("Unexpected failure: \(error)")
                                                    case .success(_, let data):
                                                        XCTAssertEqual(data.count, 0)

                                                        self.completion.fulfill()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        wait(for: [completion], timeout: 10)
    }

    func testPagingOufOfOrderPumpEvents() {
        populateInitialEvents {
            self.doseStore.insulinDeliveryStore.test_currentDate = self.f("2022-01-10T01:25:00Z")
            self.limit = 4

            let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T00:30:00Z"),
                                                           endDate: self.f("2022-01-10T00:35:00Z"),
                                                           value: 2.5,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "d86434bba46f499ea23c25e98c66687e")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T00:55:00Z"),       // This should come after the next one
                                                           endDate: self.f("2022-01-10T01:05:00Z"),
                                                           value: 1.5,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "740f67b2c29b4a64a918046a8b09c5f3")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T00:40:00Z"),
                                                           endDate: self.f("2022-01-10T00:45:00Z"),
                                                           value: 2.0,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "5c0c229d093f40869e8685cb5eb53c15")),
                              NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                           startDate: self.f("2022-01-10T01:15:00Z"),
                                                           endDate: self.f("2022-01-10T01:20:00Z"),
                                                           value: 1.0,
                                                           unit: .unitsPerHour,
                                                           deliveredUnits: nil,
                                                           syncIdentifier: "1e96187ea69643b2a69e94d3c539fd64"))]
            self.doseStore.addPumpEvents(pumpEvents, lastReconciliation: self.f("2022-01-10T01:25:00Z")) { error in
                XCTAssertNil(error)
                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                    switch result {
                    case .failure(let error):
                        XCTFail("Unexpected failure: \(error)")
                    case .success(let queryAnchor, let data):
                        XCTAssertEqual(data.count, 2)

                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:30:00Z"))
                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[0].dose?.type, .tempBasal)
                        XCTAssertEqual(data[0].dose?.unitsPerHour, 2.5)
                        XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[0].mutable)
                        XCTAssertEqual(data[0].syncIdentifier, "d86434bba46f499ea23c25e98c66687e")

                        XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T00:35:00Z"))
                        XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T00:40:00Z"))
                        XCTAssertEqual(data[1].dose?.type, .basal)
                        XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                        XCTAssertFalse(data[1].mutable)

                        self.queryAnchor = queryAnchor

                        self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                            switch result {
                            case .failure(let error):
                                XCTFail("Unexpected failure: \(error)")
                            case .success(let queryAnchor, let data):
                                XCTAssertEqual(data.count, 4)

                                XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T00:40:00Z"))
                                XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T00:45:00Z"))
                                XCTAssertEqual(data[0].dose?.type, .tempBasal)
                                XCTAssertEqual(data[0].dose?.unitsPerHour, 2.0)
                                XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                                XCTAssertFalse(data[0].mutable)
                                XCTAssertEqual(data[0].syncIdentifier, "5c0c229d093f40869e8685cb5eb53c15")

                                XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T00:45:00Z"))
                                XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T00:55:00Z"))
                                XCTAssertEqual(data[1].dose?.type, .basal)
                                XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                                XCTAssertFalse(data[1].mutable)

                                XCTAssertEqual(data[2].dose?.startDate, self.f("2022-01-10T00:55:00Z"))
                                XCTAssertEqual(data[2].dose?.endDate, self.f("2022-01-10T01:00:00Z"))
                                XCTAssertEqual(data[2].dose?.type, .tempBasal)
                                XCTAssertEqual(data[2].dose?.unitsPerHour, 1.5)
                                XCTAssertEqual(data[2].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.5)
                                XCTAssertFalse(data[2].mutable)
                                XCTAssertEqual(data[2].syncIdentifier, "740f67b2c29b4a64a918046a8b09c5f3 1/2")

                                XCTAssertEqual(data[3].dose?.startDate, self.f("2022-01-10T01:00:00Z"))
                                XCTAssertEqual(data[3].dose?.endDate, self.f("2022-01-10T01:05:00Z"))
                                XCTAssertEqual(data[3].dose?.type, .tempBasal)
                                XCTAssertEqual(data[3].dose?.unitsPerHour, 1.5)
                                XCTAssertEqual(data[3].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                                XCTAssertFalse(data[3].mutable)
                                XCTAssertEqual(data[3].syncIdentifier, "740f67b2c29b4a64a918046a8b09c5f3 2/2")

                                self.queryAnchor = queryAnchor

                                self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                                    switch result {
                                    case .failure(let error):
                                        XCTFail("Unexpected failure: \(error)")
                                    case .success(let queryAnchor, let data):
                                        XCTAssertEqual(data.count, 2)

                                        XCTAssertEqual(data[0].dose?.startDate, self.f("2022-01-10T01:05:00Z"))
                                        XCTAssertEqual(data[0].dose?.endDate, self.f("2022-01-10T01:15:00Z"))
                                        XCTAssertEqual(data[0].dose?.type, .basal)
                                        XCTAssertEqual(data[0].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                                        XCTAssertFalse(data[0].mutable)

                                        XCTAssertEqual(data[1].dose?.startDate, self.f("2022-01-10T01:15:00Z"))
                                        XCTAssertEqual(data[1].dose?.endDate, self.f("2022-01-10T01:20:00Z"))
                                        XCTAssertEqual(data[1].dose?.type, .tempBasal)
                                        XCTAssertEqual(data[1].dose?.unitsPerHour, 1.0)
                                        XCTAssertEqual(data[1].dose?.scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour), 0.7)
                                        XCTAssertFalse(data[1].mutable)
                                        XCTAssertEqual(data[1].syncIdentifier, "1e96187ea69643b2a69e94d3c539fd64")

                                        self.queryAnchor = queryAnchor

                                        self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                                            switch result {
                                            case .failure(let error):
                                                XCTFail("Unexpected failure: \(error)")
                                            case .success(_, let data):
                                                XCTAssertEqual(data.count, 0)

                                                self.completion.fulfill()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        wait(for: [completion], timeout: 10)
    }

    private func populateInitialEvents(_ completion: @escaping () -> Void) {
        doseStore.insulinDeliveryStore.test_currentDate = f("2022-01-10T00:35:00Z")

        let pumpEvents = [NewPumpEvent(dose: DoseEntry(type: .resume,
                                                       startDate: f("2022-01-10T00:10:00Z"),
                                                       value: 0,
                                                       unit: .units,
                                                       syncIdentifier: "e2bae2b6b317416a9816edab137c9278")),
                          NewPumpEvent(dose: DoseEntry(type: .tempBasal,
                                                       startDate: f("2022-01-10T00:15:00Z"),
                                                       endDate: f("2022-01-10T00:30:00Z"),
                                                       value: 4.5,
                                                       unit: .unitsPerHour,
                                                       deliveredUnits: nil,
                                                       syncIdentifier: "068f9253370443969c9b23c59383df10"))]
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        doseStore.addPumpEvents(pumpEvents, lastReconciliation: f("2022-01-10T00:30:00Z")) { error in
            XCTAssertNil(error)
            self.doseStore.executePumpQuery(fromQueryAnchor: self.queryAnchor, limit: self.limit) { result in
                switch result {
                case .failure(let error):
                    XCTFail("Unexpected failure: \(error)")
                case .success(let queryAnchor, let data):
                    self.queryAnchor = queryAnchor
                    XCTAssertEqual(data.count, 5)
                }
                dispatchGroup.leave()
            }
        }
        dispatchGroup.wait()
        completion()
    }

    private func f(_ dateString: String) -> Date {
        return dateFormatter.date(from: dateString)!
    }

    private let dateFormatter = ISO8601DateFormatter()
}

class DoseStoreCriticalEventLogTests: PersistenceControllerTestCase {
    let insulinModel = WalshInsulinModel(actionDuration: .hours(4))
    let basalProfile = BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]])
    let insulinSensitivitySchedule = InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]])

    var doseStore: DoseStore!
    var outputStream: MockOutputStream!
    var progress: Progress!
    
    override func setUp() {
        super.setUp()

        let persistedDate = dateFormatter.date(from: "2100-01-02T03:00:00Z")!
        let url = URL(string: "http://a.b.com")!
        let events = [PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:08:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil, isMutable: false),
                      PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:10:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil, isMutable: false),
                      PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:04:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil, isMutable: false),
                      PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:06:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil, isMutable: false),
                      PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:02:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil, isMutable: false)]

        doseStore = DoseStore(healthStore: HKHealthStoreMock(),
                              cacheStore: cacheStore,
                              observationEnabled: false,
                              insulinModelProvider: StaticInsulinModelProvider(insulinModel),
                              longestEffectDuration: insulinModel.effectDuration,
                              basalProfile: basalProfile,
                              insulinSensitivitySchedule: insulinSensitivitySchedule,
                              provenanceIdentifier: Bundle.main.bundleIdentifier!)
        XCTAssertNil(doseStore.addPumpEvents(events: events))

        outputStream = MockOutputStream()
        progress = Progress()
    }

    override func tearDown() {
        doseStore = nil

        super.tearDown()
    }
    
    func testExportProgressTotalUnitCount() {
        switch doseStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                      endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 3 * 1)
        }
    }
    
    func testExportProgressTotalUnitCountEmpty() {
        switch doseStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                                      endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 0)
        }
    }

    func testExport() {
        XCTAssertNil(doseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                      endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                      to: outputStream,
                                      progress: progress))
        XCTAssertEqual(outputStream.string, """
[
{"createdAt":"2100-01-02T03:00:00.000Z","date":"2100-01-02T03:08:00.000Z","duration":0,"insulinType":0,"modificationCounter":1,"mutable":false,"uploaded":false},
{"createdAt":"2100-01-02T03:00:00.000Z","date":"2100-01-02T03:04:00.000Z","duration":0,"insulinType":0,"modificationCounter":3,"mutable":false,"uploaded":false},
{"createdAt":"2100-01-02T03:00:00.000Z","date":"2100-01-02T03:06:00.000Z","duration":0,"insulinType":0,"modificationCounter":4,"mutable":false,"uploaded":false}
]
"""
        )
        XCTAssertEqual(progress.completedUnitCount, 3 * 1)
    }
    
    func testExportEmpty() {
        XCTAssertNil(doseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                      endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!,
                                      to: outputStream,
                                      progress: progress))
        XCTAssertEqual(outputStream.string, "[]")
        XCTAssertEqual(progress.completedUnitCount, 0)
    }

    func testExportCancelled() {
        progress.cancel()
        XCTAssertEqual(doseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                        endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                        to: outputStream,
                                        progress: progress) as? CriticalEventLogError, CriticalEventLogError.cancelled)
    }

    private let dateFormatter = ISO8601DateFormatter()
}

class DoseStoreEffectTests: PersistenceControllerTestCase {
    var doseStore: DoseStore!

    var insulinSensitivitySchedule: InsulinSensitivitySchedule {
        return InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0.0, value: 40.0)], timeZone: .currentFixed)!
    }

    let dateFormatter = ISO8601DateFormatter.localTimeDate()

    override func setUp() {
        super.setUp()
        let healthStore = HKHealthStoreMock()
        let exponentialInsulinModel: InsulinModel = ExponentialInsulinModelPreset.rapidActingAdult
        let startDate = dateFormatter.date(from: "2015-07-13T12:00:00")!

        doseStore = DoseStore(
            healthStore: healthStore,
            observeHealthKitSamplesFromOtherApps: false,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(exponentialInsulinModel),
            longestEffectDuration: exponentialInsulinModel.effectDuration,
            basalProfile: BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 1.0)]),
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            overrideHistory: TemporaryScheduleOverrideHistory(),
            provenanceIdentifier: Bundle.main.bundleIdentifier!,
            test_currentDate: startDate
        )
    }
    
    override func tearDown() {
        doseStore = nil
        
        super.tearDown()
    }

    func loadGlucoseEffectFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func loadDoseFixture(_ resourceName: String) -> [DoseEntry] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.compactMap {
            guard let unit = DoseUnit(rawValue: $0["unit"] as! String),
                let pumpType = PumpEventType(rawValue: $0["type"] as! String),
                let type = DoseType(pumpEventType: pumpType)
                else {
                    return nil
            }

            var scheduledBasalRate: HKQuantity? = nil
            if let scheduled = $0["scheduled"] as? Double {
                scheduledBasalRate = HKQuantity(unit: unit.unit, doubleValue: scheduled)
            }

            return DoseEntry(
                type: type,
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                endDate: dateFormatter.date(from: $0["end_at"] as! String)!,
                value: $0["amount"] as! Double,
                unit: unit,
                description: $0["description"] as? String,
                syncIdentifier: $0["raw"] as? String,
                scheduledBasalRate: scheduledBasalRate
            )
        }
    }

    func injectDoseEvents(from fixture: String) {
        let events = loadDoseFixture(fixture).map {
            NewPumpEvent(
                date: $0.startDate,
                dose: $0,
                isMutable: false,
                raw: Data(UUID().uuidString.utf8),
                title: "",
                type: $0.type.pumpEventType
            )
        }

        doseStore.addPumpEvents(events, lastReconciliation: nil) { error in
            if error != nil {
                XCTFail("Doses should be added successfully to dose store")
            }
        }
    }

    func testGlucoseEffectFromTempBasal() {
        injectDoseEvents(from: "basal_dose")
        let output = loadGlucoseEffectFixture("effect_from_basal_output_exponential")

        var insulinEffects: [GlucoseEffect]!
        let startDate = dateFormatter.date(from: "2015-07-13T12:00:00")!
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        doseStore.getGlucoseEffects(start: startDate) { (result) -> Void in
            switch result {
            case .failure(let error):
                print(error)
                XCTFail("Mock should always return success")
            case .success(let effects):
                insulinEffects = effects
            }
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(output.count, insulinEffects.count)

        for (expected, calculated) in zip(output, insulinEffects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 1.0, String(describing: expected.startDate))
        }
    }

    func testGlucoseEffectFromTempBasalWithOldDoses() {
        injectDoseEvents(from: "basal_dose_with_expired")
        let output = loadGlucoseEffectFixture("effect_from_basal_output_exponential")

        var insulinEffects: [GlucoseEffect]!
        let startDate = dateFormatter.date(from: "2015-07-13T12:00:00")!
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        doseStore.getGlucoseEffects(start: startDate) { (result) -> Void in
            switch result {
            case .failure(let error):
                print(error)
                XCTFail("Mock should always return success")
            case .success(let effects):
                insulinEffects = effects
            }
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(output.count, insulinEffects.count)

        for (expected, calculated) in zip(output, insulinEffects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 1.0, String(describing: expected.startDate))
        }
    }

    func testGlucoseEffectFromHistory() {
        injectDoseEvents(from: "dose_history_with_delivered_units")
        let output = loadGlucoseEffectFixture("effect_from_history_exponential_delivered_units_output")

        var insulinEffects: [GlucoseEffect]!
        let startDate = dateFormatter.date(from: "2016-01-30T15:40:49")!
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        doseStore.getGlucoseEffects(start: startDate) { (result) -> Void in
            switch result {
            case .failure(let error):
                print(error)
                XCTFail("Mock should always return success")
            case .success(let effects):
                insulinEffects = effects
            }
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(output.count, insulinEffects.count)

        for (expected, calculated) in zip(output, insulinEffects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 1.0, String(describing: expected.startDate))
        }
    }
}

fileprivate extension UUID {
    var hexidecimalString: String { data.hexadecimalString }
}

fileprivate extension NewPumpEvent {
    init(date: Date, type: PumpEventType, alarmType: PumpAlarmType? = nil, syncIdentifier: String) {
        self.init(date: date, dose: nil, isMutable: false, raw: Data(hexadecimalString: syncIdentifier)!, title: syncIdentifier, type: type, alarmType: alarmType)
    }

    init(dose: DoseEntry, isMutable: Bool = false) {
        self.init(date: dose.startDate, dose: dose, isMutable: isMutable, raw: Data(hexadecimalString: dose.syncIdentifier!)!, title: dose.syncIdentifier!)
    }
}
