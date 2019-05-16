//
//  DiagnosticLogTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 8/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest
import os.log

@testable import LoopKit


class DiagnosticLogTests: XCTestCase {
    
    fileprivate var testLog: TestLog!
    
    override func setUp() {
        testLog = TestLog()
        SharedLogging.instance = testLog
    }
    
    override func tearDown() {
        SharedLogging.instance = nil
        testLog = nil
    }
    
    func testInitializer() {
        XCTAssertNotNil(DiagnosticLog(subsystem: "subsystem", category: "category"))
    }
    
    func testDebugWithoutArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "debug subsystem", category: "debug category")
        
        diagnosticLog.debug("debug message without arguments")
        
        XCTAssertEqual(testLog.message.description, "debug message without arguments")
        XCTAssertEqual(testLog.subsystem, "debug subsystem")
        XCTAssertEqual(testLog.category, "debug category")
        XCTAssertEqual(testLog.type, .debug)
        XCTAssertEqual(testLog.args.count, 0)
    }
    
    func testDebugWithArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "debug subsystem", category: "debug category")
        
        diagnosticLog.debug("debug message with arguments", "a")
        
        XCTAssertEqual(testLog.message.description, "debug message with arguments")
        XCTAssertEqual(testLog.subsystem, "debug subsystem")
        XCTAssertEqual(testLog.category, "debug category")
        XCTAssertEqual(testLog.type, .debug)
        XCTAssertEqual(testLog.args.count, 1)
    }
    
    func testInfoWithoutArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "info subsystem", category: "info category")
        
        diagnosticLog.info("info message without arguments")
        
        XCTAssertEqual(testLog.message.description, "info message without arguments")
        XCTAssertEqual(testLog.subsystem, "info subsystem")
        XCTAssertEqual(testLog.category, "info category")
        XCTAssertEqual(testLog.type, .info)
        XCTAssertEqual(testLog.args.count, 0)
    }
    
    func testInfoWithArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "info subsystem", category: "info category")
        
        diagnosticLog.info("info message with arguments", "a", "b")
        
        XCTAssertEqual(testLog.message.description, "info message with arguments")
        XCTAssertEqual(testLog.subsystem, "info subsystem")
        XCTAssertEqual(testLog.category, "info category")
        XCTAssertEqual(testLog.type, .info)
        XCTAssertEqual(testLog.args.count, 2)
    }
    
    func testDefaultWithoutArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "default subsystem", category: "default category")
        
        diagnosticLog.default("default message without arguments")
        
        XCTAssertEqual(testLog.message.description, "default message without arguments")
        XCTAssertEqual(testLog.subsystem, "default subsystem")
        XCTAssertEqual(testLog.category, "default category")
        XCTAssertEqual(testLog.type, .default)
        XCTAssertEqual(testLog.args.count, 0)
    }
    
    func testDefaultWithArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "default subsystem", category: "default category")
        
        diagnosticLog.default("default message with arguments", "a", "b", "c")
        
        XCTAssertEqual(testLog.message.description, "default message with arguments")
        XCTAssertEqual(testLog.subsystem, "default subsystem")
        XCTAssertEqual(testLog.category, "default category")
        XCTAssertEqual(testLog.type, .default)
        XCTAssertEqual(testLog.args.count, 3)
    }
    
    func testErrorWithoutArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "error subsystem", category: "error category")
        
        diagnosticLog.error("error message without arguments")
        
        XCTAssertEqual(testLog.message.description, "error message without arguments")
        XCTAssertEqual(testLog.subsystem, "error subsystem")
        XCTAssertEqual(testLog.category, "error category")
        XCTAssertEqual(testLog.type, .error)
        XCTAssertEqual(testLog.args.count, 0)
    }
    
    func testErrorWithArguments() {
        let diagnosticLog = DiagnosticLog(subsystem: "error subsystem", category: "error category")
        
        diagnosticLog.error("error message with arguments", "a", "b", "c", "d")
        
        XCTAssertEqual(testLog.message.description, "error message with arguments")
        XCTAssertEqual(testLog.subsystem, "error subsystem")
        XCTAssertEqual(testLog.category, "error category")
        XCTAssertEqual(testLog.type, .error)
        XCTAssertEqual(testLog.args.count, 4)
    }
    
}


fileprivate class TestLog: Logging {
    
    var message: StaticString!
    
    var subsystem: String!
    
    var category: String!
    
    var type: OSLogType!
    
    var args: [CVarArg]!
    
    init() {}
    
    func log (_ message: StaticString, subsystem: String, category: String, type: OSLogType, _ args: [CVarArg]) {
        self.message = message
        self.subsystem = subsystem
        self.category = category
        self.type = type
        self.args = args
    }
}
