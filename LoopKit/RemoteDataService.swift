//
//  RemoteDataService.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

// MARK: - RemoteDataService

public protocol RemoteDataServiceDelegate: AnyObject {

    /// The delegate to perform status remote data queries.
    var statusRemoteDataQueryDelegate: StatusRemoteDataQueryDelegate? { get }

    /// The delegate to perform settings remote data queries.
    var settingsRemoteDataQueryDelegate: SettingsRemoteDataQueryDelegate? { get }

    /// The delegate to perform glucose remote data queries.
    var glucoseRemoteDataQueryDelegate: GlucoseRemoteDataQueryDelegate? { get }

    /// The delegate to perform dose remote data queries.
    var doseRemoteDataQueryDelegate: DoseRemoteDataQueryDelegate? { get }

    /// The delegate to perform carb remote data queries.
    var carbRemoteDataQueryDelegate: CarbRemoteDataQueryDelegate? { get }

}

public protocol RemoteDataService: Service {

    /// The delegate for the remote data service.
    var remoteDataServiceDelegate: RemoteDataServiceDelegate? { get set }

    /// Synchronize all remote data with the service.
    func synchronizeRemoteData(completion: @escaping (_ result: Result<Bool, Error>) -> Void)

}

// MARK: - RemoteDataError

/**
 An error that can occur during a remote data operation.
 */
public enum RemoteDataError: Error {

    /// Any query failure.
    case queryFailure(Error)

    /// A query timeout.
    case queryTimeout

    /// Any network failure.
    case networkFailure(Error)

    /// A network timeout.
    case networkTimeout

}

// MARK: - StoredAndDeletedRemoteData

/**
 A remote data query can return data that must be stored and data that must be deleted. This
 struct captures both into a single entity. The type of the stored and deleted data array is
 generic.
 */
public struct StoredAndDeletedRemoteData<S, D> {

    public var stored: [S]

    public var deleted: [D]

    public init() {
        self.stored = []
        self.deleted = []
    }

    public var isEmpty: Bool {
        return stored.isEmpty && deleted.isEmpty
    }

    public var count: Int {
        return stored.count + deleted.count
    }

}

// MARK: - QueryAnchor

/**
 A query anchor must be explicitly initializable and raw representable.
 */
public protocol QueryAnchor: RawRepresentable {

    init()

}

// MARK: - CoreDataQueryAnchor

/**
 A basic core data query anchor that uses a modification counter to track changes.
 */
public struct CoreDataQueryAnchor: QueryAnchor {

    public typealias RawValue = [String: Any]

    public var modificationCounter: Int64?

    public init() {}

    public init?(rawValue: RawValue) {
        if let modificationCounter = rawValue["modificationCounter"] as? Int64 {
            self.modificationCounter = modificationCounter
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [:]
        if let modificationCounter = modificationCounter {
            rawValue["modificationCounter"] = modificationCounter
        }
        return rawValue
    }

}

// MARK: - StoredAndDeletedCoreDataQueryAnchor

/**
 A core data query anchor that uses modification counters to track changes to both
 stored and deleted data.
 */
public struct StoredAndDeletedCoreDataQueryAnchor: QueryAnchor {

    public typealias RawValue = [String: Any]

    public var storedModificationCounter: Int64?

    public var deletedModificationCounter: Int64?

    public init() {}

    public init?(rawValue: RawValue) {
        if let storedModificationCounter = rawValue["storedModificationCounter"] as? Int64 {
            self.storedModificationCounter = storedModificationCounter
        }
        if let deletedModificationCounter = rawValue["deletedModificationCounter"] as? Int64 {
            self.deletedModificationCounter = deletedModificationCounter
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [:]
        if let storedModificationCounter = storedModificationCounter {
            rawValue["storedModificationCounter"] = storedModificationCounter
        }
        if let deletedModificationCounter = deletedModificationCounter {
            rawValue["deletedModificationCounter"] = deletedModificationCounter
        }
        return rawValue
    }

}

// MARK: - DatedQueryAnchor

/**
 An query anchor that provides a start and end date in addition to the underlying
 query anchor semantics.
 */
public struct DatedQueryAnchor<A> where A: QueryAnchor {

    public typealias RawValue = [String: Any]

    public let startDate: Date?

    public let endDate: Date?

    public var anchor: A

    public init(startDate: Date? = nil, endDate: Date? = nil) {
        self.init(startDate: startDate, endDate: endDate, anchor: A())
    }

    init(startDate: Date?, endDate: Date?, anchor: A) {
        self.startDate = startDate
        self.endDate = endDate
        self.anchor = anchor
    }

    public init?(rawValue: RawValue) {
        guard let rawAnchor = rawValue["anchor"] as? A.RawValue,
            let anchor = A(rawValue: rawAnchor) else {
                return nil
        }
        self.init(startDate: rawValue["startDate"] as? Date, endDate: rawValue["endDate"] as? Date, anchor: anchor)
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [:]
        if let startDate = startDate {
            rawValue["startDate"] = startDate
        }
        if let endDate = endDate {
            rawValue["endDate"] = endDate
        }
        rawValue["anchor"] = anchor.rawValue
        return rawValue
    }

}

// MARK: - QueryAnchoredRemoteData

/**
 Any data returned by a remote data query is always associated with an query anchor to be used
 for the next query. Assuming the query and subsequent processing (eg. upload) is successful
 the query anchor should be persisted and used on the next query.
 */
public struct QueryAnchoredRemoteData<A, D> where A: QueryAnchor {

    public var anchor: DatedQueryAnchor<A>

    public var data: D

    public init(anchor: DatedQueryAnchor<A>, data: D) {
        self.anchor = anchor
        self.data = data
    }

}

// MARK: - QueryAnchoredRemoteDataQuery

/**
 Base class for all remote data queries that adds query anchor logic to allow
 a single query to respond to multiple, sequential queries.
 */
public class QueryAnchoredRemoteDataQuery<A>: RawRepresentable where A: QueryAnchor {

    public typealias RawValue = [String: Any]

    public private(set) var anchor: DatedQueryAnchor<A>

    private(set) var pendingAnchor: DatedQueryAnchor<A>?

    public var limit: Int?

    public required init(startDate: Date? = nil, endDate: Date? = nil) {
        self.anchor = DatedQueryAnchor<A>(startDate: startDate, endDate: endDate)
    }

    public required init?(rawValue: RawValue) {
        guard let anchorRawValue = rawValue["anchor"] as? DatedQueryAnchor<A>.RawValue,
            let anchor = DatedQueryAnchor<A>(rawValue: anchorRawValue)
            else {
                return nil
        }
        self.anchor = anchor
    }

    public var rawValue: RawValue {
        return [
            "anchor": anchor.rawValue
        ]
    }

    public func pending(_ anchor: DatedQueryAnchor<A>) {
        pendingAnchor = anchor
    }

    public func abort() {
        pendingAnchor = nil
    }

    public func commit() {
        if let pendingAnchor = pendingAnchor {
            anchor = pendingAnchor
            self.pendingAnchor = nil
        }
    }

    public func reset() {
        anchor = DatedQueryAnchor<A>(startDate: anchor.startDate, endDate: anchor.endDate)
        pendingAnchor = nil
    }

}

// MARK: - StatusRemoteData

/**
 Concrete type for status remote data.
 */
public typealias StatusRemoteData = [StoredStatus]

/**
 Concrete type for status query anchor.
 */
public typealias StatusQueryAnchor = CoreDataQueryAnchor

/**
 Concrete type for status query anchor remote data.
 */
public typealias StatusQueryAnchoredRemoteData = QueryAnchoredRemoteData<StatusQueryAnchor, StatusRemoteData>

/**
 Delegate protocol for a status remote data query.
 */
public protocol StatusRemoteDataQueryDelegate: AnyObject {

    /**
     Query for any status data using the specified anchor and limit. Invokes the completion function with success or failure.

     - Parameter anchor: The anchor with which to perform the query.
     - Parameter limit: The maximum number of data returned from a single query including both stored and deleted data.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func queryStatusRemoteData(anchor: DatedQueryAnchor<StatusQueryAnchor>, limit: Int, completion: @escaping (Result<StatusQueryAnchoredRemoteData, Error>) -> Void)

}

/**
 Concrete type for a status remote data query. Ties together an anchored remote data query
 and the status remote data query delegate.
 */
public final class StatusRemoteDataQuery: QueryAnchoredRemoteDataQuery<StatusQueryAnchor> {

    public typealias D = StatusRemoteData

    public weak var delegate: StatusRemoteDataQueryDelegate?

    public func execute(maximumLimit: Int, completion: @escaping (Result<D, Error>) -> Void) {
        delegate!.queryStatusRemoteData(anchor: pendingAnchor ?? anchor, limit: min(limit ?? Int.max, maximumLimit)) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let anchoredData):
                self.pending(anchoredData.anchor)
                completion(.success(anchoredData.data))
            }
        }
    }

}

// MARK: - SettingsRemoteData

/**
 Concrete type for settings remote data.
 */
public typealias SettingsRemoteData = [StoredSettings]

/**
 Concrete type for settings query anchor.
 */
public typealias SettingsQueryAnchor = CoreDataQueryAnchor

/**
 Concrete type for settings query anchor remote data.
 */
public typealias SettingsQueryAnchoredRemoteData = QueryAnchoredRemoteData<SettingsQueryAnchor, SettingsRemoteData>

/**
 Delegate protocol for a settings remote data query.
 */
public protocol SettingsRemoteDataQueryDelegate: AnyObject {

    /**
     Query for any settings data using the specified anchor and limit. Invokes the completion function with success or failure.

     - Parameter anchor: The anchor with which to perform the query.
     - Parameter limit: The maximum number of data returned from a single query including both stored and deleted data.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func querySettingsRemoteData(anchor: DatedQueryAnchor<SettingsQueryAnchor>, limit: Int, completion: @escaping (Result<SettingsQueryAnchoredRemoteData, Error>) -> Void)

}

/**
 Concrete type for a settings remote data query. Ties together an anchored remote data query
 and the settings remote data query delegate.
 */
public final class SettingsRemoteDataQuery: QueryAnchoredRemoteDataQuery<SettingsQueryAnchor> {

    public typealias D = SettingsRemoteData

    public weak var delegate: SettingsRemoteDataQueryDelegate?

    public func execute(maximumLimit: Int, completion: @escaping (Result<D, Error>) -> Void) {
        delegate!.querySettingsRemoteData(anchor: pendingAnchor ?? anchor, limit: min(limit ?? Int.max, maximumLimit)) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let anchoredData):
                self.pending(anchoredData.anchor)
                completion(.success(anchoredData.data))
            }
        }
    }

}

// MARK: - GlucoseRemoteData

/**
 Concrete type for glucose remote data.
 */
public typealias GlucoseRemoteData = [StoredGlucoseSample]

/**
 Concrete type for glucose query anchor.
 */
public typealias GlucoseQueryAnchor = CoreDataQueryAnchor

/**
 Concrete type for glucose query anchor remote data.
 */
public typealias GlucoseQueryAnchoredRemoteData = QueryAnchoredRemoteData<GlucoseQueryAnchor, GlucoseRemoteData>

/**
 Delegate protocol for a glucose remote data query.
 */
public protocol GlucoseRemoteDataQueryDelegate: AnyObject {

    /**
     Query for any glucose data using the specified anchor and limit. Invokes the completion function with success or failure.

     - Parameter anchor: The anchor with which to perform the query.
     - Parameter limit: The maximum number of data returned from a single query including both stored and deleted data.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func queryGlucoseRemoteData(anchor: DatedQueryAnchor<GlucoseQueryAnchor>, limit: Int, completion: @escaping (Result<GlucoseQueryAnchoredRemoteData, Error>) -> Void)

}

/**
 Concrete type for a glucose remote data query. Ties together an anchored remote data query
 and the glucose remote data query delegate.
 */
public final class GlucoseRemoteDataQuery: QueryAnchoredRemoteDataQuery<GlucoseQueryAnchor> {

    public typealias D = GlucoseRemoteData

    public weak var delegate: GlucoseRemoteDataQueryDelegate?

    public func execute(maximumLimit: Int, completion: @escaping (Result<D, Error>) -> Void) {
        delegate!.queryGlucoseRemoteData(anchor: pendingAnchor ?? anchor, limit: min(limit ?? Int.max, maximumLimit)) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let anchoredData):
                self.pending(anchoredData.anchor)
                completion(.success(anchoredData.data))
            }
        }
    }

}

// MARK: - DoseRemoteData

/**
 Concrete type for dose remote data.
 */
public typealias DoseRemoteData = [PersistedPumpEvent]

/**
 Concrete type for dose query anchor.
 */
public typealias DoseQueryAnchor = CoreDataQueryAnchor

/**
 Concrete type for dose query anchor remote data.
 */
public typealias DoseQueryAnchoredRemoteData = QueryAnchoredRemoteData<DoseQueryAnchor, DoseRemoteData>

/**
 Delegate protocol for a dose remote data query.
 */
public protocol DoseRemoteDataQueryDelegate: AnyObject {

    /**
     Query for any dose data using the specified anchor and limit. Invokes the completion function with success or failure.

     - Parameter anchor: The anchor with which to perform the query.
     - Parameter limit: The maximum number of data returned from a single query including both stored and deleted data.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func queryDoseRemoteData(anchor: DatedQueryAnchor<DoseQueryAnchor>, limit: Int, completion: @escaping (Result<DoseQueryAnchoredRemoteData, Error>) -> Void)

}

/**
 Concrete type for a dose remote data query. Ties together an anchored remote data query
 and the dose remote data query delegate.
 */
public final class DoseRemoteDataQuery: QueryAnchoredRemoteDataQuery<DoseQueryAnchor> {

    public typealias D = DoseRemoteData

    public weak var delegate: DoseRemoteDataQueryDelegate?

    public func execute(maximumLimit: Int, completion: @escaping (Result<D, Error>) -> Void) {
        delegate!.queryDoseRemoteData(anchor: pendingAnchor ?? anchor, limit: min(limit ?? Int.max, maximumLimit)) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let anchoredData):
                self.pending(anchoredData.anchor)
                completion(.success(anchoredData.data))
            }
        }
    }

}

// MARK: - CarbRemoteData

/**
 Concrete type for carb remote data.
 */
public typealias CarbRemoteData = StoredAndDeletedRemoteData<StoredCarbEntry, DeletedCarbEntry>

/**
 Concrete type for carb query anchor.
 */
public typealias CarbQueryAnchor = StoredAndDeletedCoreDataQueryAnchor

/**
 Concrete type for carb query anchor remote data.
 */
public typealias CarbQueryAnchoredRemoteData = QueryAnchoredRemoteData<CarbQueryAnchor, CarbRemoteData>

/**
 Delegate protocol for a carb remote data query.
 */
public protocol CarbRemoteDataQueryDelegate: AnyObject {

    /**
     Query for any carb data using the specified anchor and limit. Invokes the completion function with success or failure.

     - Parameter anchor: The anchor with which to perform the query.
     - Parameter limit: The maximum number of data returned from a single query including both stored and deleted data.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func queryCarbRemoteData(anchor: DatedQueryAnchor<CarbQueryAnchor>, limit: Int, completion: @escaping (Result<CarbQueryAnchoredRemoteData, Error>) -> Void)

}

/**
 Concrete type for a carb remote data query. Ties together an anchored remote data query
 and the carb remote data query delegate.
 */
public final class CarbRemoteDataQuery: QueryAnchoredRemoteDataQuery<CarbQueryAnchor> {

    public typealias D = CarbRemoteData

    public weak var delegate: CarbRemoteDataQueryDelegate?

    public func execute(maximumLimit: Int, completion: @escaping (Result<D, Error>) -> Void) {
        delegate!.queryCarbRemoteData(anchor: pendingAnchor ?? anchor, limit: min(limit ?? Int.max, maximumLimit)) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let anchoredData):
                self.pending(anchoredData.anchor)
                completion(.success(anchoredData.data))
            }
        }
    }

}
