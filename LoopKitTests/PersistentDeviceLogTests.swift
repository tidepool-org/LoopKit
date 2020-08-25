//
//  PersistentDeviceLogTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 8/26/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit

class PersistentDeviceLogCriticalEventLogTests: XCTestCase {
    var persistentDeviceLog: PersistentDeviceLog!
    var outputStream: MockOutputStream!
    var progressor: MockEstimatedDurationProgressor!

    override func setUp() {
        super.setUp()

        let entries = [StoredDeviceLogEntry(type: .delegateResponse, managerIdentifier: "m1", deviceIdentifier: "d1", message: "Message 1", timestamp: dateFormatter.date(from: "2100-01-02T03:08:00Z")!),
                       StoredDeviceLogEntry(type: .receive, managerIdentifier: "m2", deviceIdentifier: "d2", message: "Message 2", timestamp: dateFormatter.date(from: "2100-01-02T03:10:00Z")!),
                       StoredDeviceLogEntry(type: .send, managerIdentifier: "m3", deviceIdentifier: "d3", message: "Message 3", timestamp: dateFormatter.date(from: "2100-01-02T03:04:00Z")!),
                       StoredDeviceLogEntry(type: .delegate, managerIdentifier: "m4", deviceIdentifier: "d4", message: "Message 4", timestamp: dateFormatter.date(from: "2100-01-02T03:06:00Z")!),
                       StoredDeviceLogEntry(type: .connection, managerIdentifier: "m5", deviceIdentifier: "d5", message: "Message 5", timestamp: dateFormatter.date(from: "2100-01-02T03:02:00Z")!)]

        persistentDeviceLog = PersistentDeviceLog(storageFile: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString), maxEntryAge: .hours(1))
        XCTAssertNil(persistentDeviceLog.addStoredDeviceLogEntries(entries: entries))

        outputStream = MockOutputStream()
        progressor = MockEstimatedDurationProgressor()
    }

    override func tearDown() {
        persistentDeviceLog = nil

        super.tearDown()
    }

    func testExportEstimatedDuration() {
        switch persistentDeviceLog.exportEstimatedDuration(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                     endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let estimatedDuration):
            XCTAssertEqual(estimatedDuration, 3 * 0.0006, accuracy: 0.0001)
        }
    }

    func testExportEstimatedDurationEmpty() {
        switch persistentDeviceLog.exportEstimatedDuration(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                                     endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let estimatedDuration):
            XCTAssertEqual(estimatedDuration, 0)
        }
    }

    func testExport() {
        XCTAssertNil(persistentDeviceLog.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                          endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                          to: outputStream,
                                          progressor: progressor))
        XCTAssertEqual(outputStream.string, """
[
{"deviceIdentifier":"d1","managerIdentifier":"m1","message":"Message 1","modificationCounter":1,"timestamp":"2100-01-02T03:08:00.000Z","type":"delegateResponse"},
{"deviceIdentifier":"d3","managerIdentifier":"m3","message":"Message 3","modificationCounter":3,"timestamp":"2100-01-02T03:04:00.000Z","type":"send"},
{"deviceIdentifier":"d4","managerIdentifier":"m4","message":"Message 4","modificationCounter":4,"timestamp":"2100-01-02T03:06:00.000Z","type":"delegate"}
]
"""
        )
        XCTAssertEqual(progressor.estimatedDuration, 3 * 0.0006, accuracy: 0.0001)
    }

    func testExportEmpty() {
        XCTAssertNil(persistentDeviceLog.export(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                          endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!,
                                          to: outputStream,
                                          progressor: progressor))
        XCTAssertEqual(outputStream.string, "[]")
        XCTAssertEqual(progressor.estimatedDuration, 0)
    }

    func testExportCancelled() {
        progressor.isCancelled = true
        XCTAssertEqual(persistentDeviceLog.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                            endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                            to: outputStream,
                                            progressor: progressor) as? CriticalEventLogError, CriticalEventLogError.cancelled)
    }

    private let dateFormatter = ISO8601DateFormatter()
}
