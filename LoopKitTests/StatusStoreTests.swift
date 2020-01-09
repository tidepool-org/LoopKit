//
//  StatusStoreTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 1/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class StatusStorePersistenceTests: XCTestCase, StatusStoreCacheStore, StatusStoreDelegate {

    var statusStore: StatusStore!

    override func setUp() {
        super.setUp()

        statusStoreHasUpdatedStatusDataHandler = nil
        statusStoreModificationCounter = nil
        statusStore = StatusStore(storeCache: self)
        statusStore.delegate = self
    }

    override func tearDown() {
        statusStore.delegate = nil
        statusStore = nil
        statusStoreModificationCounter = nil
        statusStoreHasUpdatedStatusDataHandler = nil

        super.tearDown()
    }

    // MARK: - StatusStoreCacheStore

    var statusStoreModificationCounter: Int64?

    // MARK: - StatusStoreDelegate

    var statusStoreHasUpdatedStatusDataHandler: ((_ : StatusStore) -> Void)?

    func statusStoreHasUpdatedStatusData(_ statusStore: StatusStore) {
        statusStoreHasUpdatedStatusDataHandler?(statusStore)
    }

    // MARK: -

    func testStoreStatus() {
        let storeStatusHandler = expectation(description: "Store status handler")
        let storeStatusCompletion = expectation(description: "Store status completion")

        var handlerInvocation = 0

        statusStoreHasUpdatedStatusDataHandler = { statusStore in
            handlerInvocation += 1

            switch handlerInvocation {
            case 1:
                storeStatusHandler.fulfill()
            default:
                XCTFail("Unexpected handler invocation")
            }
        }

        statusStore.storeStatus(StoredStatus()) {
            XCTAssertEqual(self.statusStoreModificationCounter, 1)
            storeStatusCompletion.fulfill()
        }

        wait(for: [storeStatusHandler, storeStatusCompletion], timeout: 2, enforceOrder: true)
    }

    func testStoreStatusMultiple() {
        let storeStatusHandler1 = expectation(description: "Store status handler 1")
        let storeStatusHandler2 = expectation(description: "Store status handler 2")
        let storeStatusCompletion1 = expectation(description: "Store status completion 1")
        let storeStatusCompletion2 = expectation(description: "Store status completion 2")

        var handlerInvocation = 0

        statusStoreHasUpdatedStatusDataHandler = { statusStore in
            handlerInvocation += 1

            switch handlerInvocation {
            case 1:
                storeStatusHandler1.fulfill()
            case 2:
                storeStatusHandler2.fulfill()
            default:
                XCTFail("Unexpected handler invocation")
            }
        }

        statusStore.storeStatus(StoredStatus()) {
            XCTAssertEqual(self.statusStoreModificationCounter, 1)
            storeStatusCompletion1.fulfill()
        }

        statusStore.storeStatus(StoredStatus()) {
            XCTAssertEqual(self.statusStoreModificationCounter, 2)
            storeStatusCompletion2.fulfill()
        }

        wait(for: [storeStatusHandler1, storeStatusCompletion1, storeStatusHandler2, storeStatusCompletion2], timeout: 2, enforceOrder: true)
    }

}

class StatusStoreQueryAnchorTests: XCTestCase {

    var rawValue: StatusStore.QueryAnchor.RawValue = [
        "modificationCounter": Int64(123)
    ]

    func testInitializerDefault() {
        let queryAnchor = StatusStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.modificationCounter, 0)
    }

    func testInitializerRawValue() {
        let queryAnchor = StatusStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.modificationCounter, 123)
    }

    func testInitializerRawValueMissingModificationCounter() {
        rawValue["modificationCounter"] = nil
        XCTAssertNil(StatusStore.QueryAnchor(rawValue: rawValue))
    }

    func testInitializerRawValueInvalidModificationCounter() {
        rawValue["modificationCounter"] = "123"
        XCTAssertNil(StatusStore.QueryAnchor(rawValue: rawValue))
    }

    func testRawValueWithDefault() {
        let rawValue = StatusStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(0))
    }

    func testRawValueWithNonDefault() {
        var queryAnchor = StatusStore.QueryAnchor()
        queryAnchor.modificationCounter = 123
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(123))
    }

}

class StatusStoreQueryTests: XCTestCase, StatusStoreCacheStore {

    var statusStore: StatusStore!
    var completion: XCTestExpectation!
    var queryAnchor: StatusStore.QueryAnchor!
    var limit: Int!

    override func setUp() {
        super.setUp()

        statusStoreModificationCounter = nil
        statusStore = StatusStore(storeCache: self)
        completion = expectation(description: "Completion")
        queryAnchor = StatusStore.QueryAnchor()
        limit = Int.max
    }

    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        statusStore = nil
        statusStoreModificationCounter = nil

        super.tearDown()
    }

    // MARK: - StatusStoreCacheStore

    var statusStoreModificationCounter: Int64?

    // MARK: -

    func testEmptyWithDefaultQueryAnchor() {
        statusStore.executeStatusQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

    func testEmptyWithMissingQueryAnchor() {
        queryAnchor = nil

        statusStore.executeStatusQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

    func testEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.modificationCounter = 1

        statusStore.executeStatusQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

    func testDataWithUnusedQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        statusStore.executeStatusQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 3)
                for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                    XCTAssertEqual(data[index].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(data[index].syncVersion, index)
                }
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithStaleQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.modificationCounter = 2

        statusStore.executeStatusQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 1)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(data[0].syncVersion, 2)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.modificationCounter = 3

        statusStore.executeStatusQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

    func testDataWithLimitZero() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        limit = 0

        statusStore.executeStatusQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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

    func testDataWithLimitCoveredByData() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        limit = 2

        statusStore.executeStatusQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 2)
                XCTAssertEqual(data.count, 2)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(data[0].syncVersion, 0)
                XCTAssertEqual(data[1].syncIdentifier, syncIdentifiers[1])
                XCTAssertEqual(data[1].syncVersion, 1)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    private func addData(withSyncIdentifiers syncIdentifiers: [String]) {
        for (index, syncIdentifier) in syncIdentifiers.enumerated() {
            var status = StoredStatus()
            status.syncIdentifier = syncIdentifier
            status.syncVersion = index
            self.statusStore.storeStatus(status) {}
        }
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }

}
