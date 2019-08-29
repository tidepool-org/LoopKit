//
//  RemoteData.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


public protocol RemoteDataDelegate: class {

    var carbRemoteDataQueryDelegate: CarbRemoteDataQueryDelegate? { get }

    var glucoseRemoteDataQueryDelegate: GlucoseRemoteDataQueryDelegate? { get }

}


public protocol RemoteData {

    var delegateQueue: DispatchQueue! { get set }

    var remoteDataDelegate: RemoteDataDelegate? { get set }

    func uploadLoopStatus(insulinOnBoard: InsulinValue?,
                          carbsOnBoard: CarbValue?,
                          predictedGlucose: [GlucoseValue]?,
                          recommendedTempBasal: (recommendation: TempBasalRecommendation, date: Date)?,
                          recommendedBolus: Double?,
                          lastTempBasal: DoseEntry?,
                          lastReservoirValue: ReservoirValue?,
                          pumpManagerStatus: PumpManagerStatus?,
                          loopError: Error?)

    func upload(pumpEvents events: [PersistedPumpEvent], fromSource source: String, completion: @escaping (Result<[URL], Error>) -> Void)

    /// Synchronize all remote data with services
    func synchronizeRemoteData(completion: @escaping (_ result: Result<Bool, Error>) -> Void)

}


// MARK: - RemoteDataError


/**
 Any error that can occur during a remote data operation.
 */
public enum RemoteDataError: Error {

    /// Any error during a query.
    case queryError(Error)

    /// A query timed out.
    case timeout

    /// Any other general error.
    case unknownError(Error)
}


// MARK: - RemoteDataAnchor


/**
 An anchor that can be used during any remote data query operation. Any specific query may have
 either a HealthKit anchor and/or a local cache anchors.
 */
public struct RemoteDataAnchor {

    public var healthKitAnchor: HKQueryAnchor?

    public var cacheStoredModifiedDate: Date?

    public var cacheDeletedModifiedDate: Date?

    public init(healthKitAnchor: HKQueryAnchor? = nil, cacheStoredModifiedDate: Date? = nil, cacheDeletedModifiedDate: Date? = nil) {
        self.healthKitAnchor = healthKitAnchor
        self.cacheStoredModifiedDate = cacheStoredModifiedDate
        self.cacheDeletedModifiedDate = cacheDeletedModifiedDate
    }

}


extension RemoteDataAnchor: RawRepresentable {

    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        if let data = rawValue["healthKitAnchor"] as? Data,
            let healthKitAnchor = NSKeyedUnarchiver.unarchiveObject(with: data) as? HKQueryAnchor {
            self.healthKitAnchor = healthKitAnchor
        }
        if let cacheStoredModifiedDate = rawValue["cacheStoredModifiedDate"] as? Date {
            self.cacheStoredModifiedDate = cacheStoredModifiedDate
        }
        if let cacheDeletedModifiedDate = rawValue["cacheDeletedModifiedDate"] as? Date {
            self.cacheDeletedModifiedDate = cacheDeletedModifiedDate
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [:]
        if let healthKitAnchor = healthKitAnchor,
            let data = try? NSKeyedArchiver.archivedData(withRootObject: healthKitAnchor, requiringSecureCoding: true) {
            rawValue["healthKitAnchor"] = data
        }
        if let cacheStoredModifiedDate = cacheStoredModifiedDate {
            rawValue["cacheStoredModifiedDate"] = cacheStoredModifiedDate
        }
        if let cacheDeletedModifiedDate = cacheDeletedModifiedDate {
            rawValue["cacheDeletedModifiedDate"] = cacheDeletedModifiedDate
        }
        return rawValue
    }

}


// MARK: - AnchoredRemoteData


/**
 Any data returned by a remote data query is always associated with an anchor to be used
 for the next query. Assuming the query and subsequent processing (eg. upload) is successful
 the anchor should be remembered and used on the next query.

 The data is Optional to indicate whether the source query returned any data.
 */
public struct AnchoredRemoteData<T> {

    public var anchor: RemoteDataAnchor

    public var data: T?

}


// MARK: - AbstractRemoteData


/**
 A remote data query can return data that must be stored and data that must be deleted. This
 struct captures both into a single entity. The type of the stored and delete data array is
 generic.
 */
public struct AbstractRemoteData<S, D> {

    public var stored: [S]

    public var deleted: [D]

    public init(stored: [S] = [], deleted: [D] = []) {
        self.stored = stored
        self.deleted = deleted
    }

    public var isEmpty: Bool {
        return stored.isEmpty && deleted.isEmpty
    }

    public var count: Int {
        return stored.count + deleted.count
    }

    public var limit: Int {
        return max(stored.count, deleted.count)
    }

    public mutating func append(contentsOf data: AbstractRemoteData<S, D>) {
        self.stored.append(contentsOf: data.stored)
        self.deleted.append(contentsOf: data.deleted)
    }

    public mutating func removeAll() {
        stored = []
        deleted = []
    }

}


extension AbstractRemoteData: CustomDebugStringConvertible {

    public var debugDescription: String {
        return ["AbstractRemoteData(",
                "stored: [",
                stored.map { String(describing: $0) }.joined(separator: ",\n"),
                "],",
                "deleted: [",
                deleted.map { String(describing: $0) }.joined(separator: ",\n"),
                "])"].joined(separator: "\n")
    }

}


// MARK: - RemoteDataQueryable


/**
 Generic protocol requirements for a remote data query. It must have an associated data type,
 a start date, end date, and limit. It must be able to be initialized with these values and
 allow the start date and end date to be modified. It must allow for a query with an maximum
 limit and the ability to abort or commit the new state of the query.
 */
public protocol RemoteDataQueryable: RawRepresentable {

    /// The associated data type returned from the query.
    associatedtype D

    /// The start date of the query, data returned must have a start date equal to or greater than this value.
    /// Nil indicates the data can have any start date.
    var startDate: Date? { get set }

    /// The end date of the query, data returned must have a end date less than this value.
    /// Nil indicates the data can have any end date.
    var endDate: Date? { get set }

    /// The maximum number of data returned from a single query including both stored and deleted data.
    var limit: Int? { get set }

    /**
     Initialize the query with start date, end date, and limit.

     - Parameter startDate: The start date of the query, data returned must have a start date equal to or greater than this value.
     - Parameter endDate: The end date of the query, data returned must have a end date less than this value.
     - Parameter limit: The maximum number of data returned from a single query including both stored and deleted data.
     */
    init(startDate: Date?, endDate: Date?, limit: Int?)

    /**
     Execute the query with an additional maximum limit. The final limit used by the query should be the lesser
     of the maximum limit and the query limit. Invokes the completion function with success or failure. If the query did
     not return data, then the result should be .success(nil).

     - Parameter maximumLimit: The maximum number of data returned from a single query including both stored and deleted data, regardless of the query limit.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func execute(maximumLimit: Int, completion: @escaping (Result<D?, RemoteDataError>) -> Void)

    /**
     Abort the query and restore any internal query settings as if the query never happened.
     */
    func abort()

    /**
     Commit the query and update any internal query settings in preparation for the next query which may
     include updating any anchors or cursors used by the query.
     */
    func commit()

}


// MARK: - AnchoredRemoteDataQuery


/**
 Base class for all remote data queries that adds query anchor logic to allow
 a single query to respond to multiple, sequential queries.
 */
public class AnchoredRemoteDataQuery: RawRepresentable {

    public typealias RawValue = [String: Any]

    public var startDate: Date? {
        didSet {
            anchor = nil
            pendingAnchor = nil
        }
    }

    public var endDate: Date? {
        didSet {
            anchor = nil
            pendingAnchor = nil
        }
    }

    public var limit: Int?

    public private(set) var anchor: RemoteDataAnchor?

    private(set) var pendingAnchor: RemoteDataAnchor?

    public required init(startDate: Date? = nil, endDate: Date? = nil, limit: Int? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.limit = limit
    }

    public required init?(rawValue: RawValue) {
        self.startDate = rawValue["startDate"] as? Date
        self.endDate = rawValue["endDate"] as? Date
        if let anchorRawValue = rawValue["anchor"] as? RemoteDataAnchor.RawValue {
            self.anchor = RemoteDataAnchor(rawValue: anchorRawValue)
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [:]
        rawValue["startDate"] = startDate
        rawValue["endDate"] = endDate
        rawValue["anchor"] = anchor?.rawValue
        return rawValue
    }

    public func pending(_ anchor: RemoteDataAnchor) {
        pendingAnchor = anchor
    }

    public func abort() {
        pendingAnchor = nil
    }

    public func commit() {
        anchor = pendingAnchor
        pendingAnchor = nil
    }

}


// MARK: - CarbRemoteData


/**
 Concrete class for carb stored and deleted data.
 */
public typealias CarbRemoteData = AbstractRemoteData<StoredCarbEntry, DeletedCarbEntry>


/**
 Concrete class for anchored carb data.
 */
public typealias AnchoredCarbRemoteData = AnchoredRemoteData<CarbRemoteData>


/**
 Delegate protocol for a carb remote data query.
 */
public protocol CarbRemoteDataQueryDelegate: AnyObject {

    /**
     Query for any carb data using the specified start date, end date, limit, and anchor.
     Invokes the completion function with success or failure.

     - Parameter startDate: The start date of the query, data returned must have a start date equal to or greater than this value.
     - Parameter endDate: The end date of the query, data returned must have a end date less than this value.
     - Parameter limit: The maximum number of data returned from a single query including both stored and deleted data.
     - Parameter anchor: The date with which to compare the receiver.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func queryCarbRemoteData(startDate: Date?, endDate: Date?, limit: Int?, anchor: RemoteDataAnchor?, completion: @escaping (Result<AnchoredCarbRemoteData, RemoteDataError>) -> Void)

}


/**
 Concrete class for a carb remote data query. Ties together an anchored remote data query
 and the carb remote data query delegate.
 */
public final class CarbRemoteDataQuery: AnchoredRemoteDataQuery, RemoteDataQueryable {

    public typealias D = CarbRemoteData

    public weak var delegate: CarbRemoteDataQueryDelegate?

    public func execute(maximumLimit: Int, completion: @escaping (Result<D?, RemoteDataError>) -> Void) {
        delegate!.queryCarbRemoteData(startDate: startDate, endDate: endDate, limit: min(limit ?? Int.max, maximumLimit), anchor: pendingAnchor ?? anchor) { result in
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
 Concrete class for glucose stored and deleted data.
 */
public typealias GlucoseRemoteData = AbstractRemoteData<StoredGlucoseSample, DeletedGlucoseSample>


/**
 Concrete class for anchored glucose data.
 */
public typealias AnchoredGlucoseRemoteData = AnchoredRemoteData<GlucoseRemoteData>


/**
 Delegate protocol for a glucose remote data query.
 */
public protocol GlucoseRemoteDataQueryDelegate: AnyObject {

    /**
     Query for any glucose data using the specified start date, end date, limit, and anchor.
     Invokes the completion function with success or failure.

     - Parameter startDate: The start date of the query, data returned must have a start date equal to or greater than this value.
     - Parameter endDate: The end date of the query, data returned must have a end date less than this value.
     - Parameter limit: The maximum number of data returned from a single query including both stored and deleted data.
     - Parameter anchor: The date with which to compare the receiver.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func queryGlucoseRemoteData(startDate: Date?, endDate: Date?, limit: Int?, anchor: RemoteDataAnchor?, completion: @escaping (Result<AnchoredGlucoseRemoteData, RemoteDataError>) -> Void)

}


/**
 Concrete class for a glucose remote data query. Ties together an anchored remote data query
 and the glucose remote data query delegate.
 */
public final class GlucoseRemoteDataQuery: AnchoredRemoteDataQuery, RemoteDataQueryable {

    public typealias D = GlucoseRemoteData

    public weak var delegate: GlucoseRemoteDataQueryDelegate?

    public func execute(maximumLimit: Int, completion: @escaping (Result<D?, RemoteDataError>) -> Void) {
        delegate!.queryGlucoseRemoteData(startDate: startDate, endDate: endDate, limit: min(limit ?? Int.max, maximumLimit), anchor: pendingAnchor ?? anchor) { result in
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

