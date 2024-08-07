//
//  PersistenceControllerTestCase.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class PersistenceControllerTestCase: XCTestCase {
 
    var cacheStore: PersistenceController!

    override func setUp() {
        super.setUp()


        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        cacheStore = PersistenceController(directoryURL: URL(fileURLWithPath: dir.absoluteString, isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true))

        print("**** Setup cacheStore at \(cacheStore.directoryURL)")

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { error in
            semaphore.signal()
        }
        semaphore.wait()
    }

    override func tearDown() {
        cacheStore.tearDown()
        cacheStore = nil

        super.tearDown()
    }

    deinit {
        cacheStore?.tearDown()
    }
    
}
