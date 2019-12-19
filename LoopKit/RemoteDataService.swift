//
//  RemoteDataService.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

/**
 Protocol for a remote data service.
*/
public protocol RemoteDataService: Service {

    /// The maximum number of carb data to synchronize with the remote data service.
    var carbDataLimit: Int { get }

    /**
     Synchronize carb data with the remote data service.

     - Parameter deleted: The deleted carb data to synchronize.
     - Parameter stored: The stored carb data to synchronize.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func synchronizeCarbData(deleted: [DeletedCarbEntry], stored: [StoredCarbEntry], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of dose data to synchronize with the remote data service.
    var doseDataLimit: Int { get }

    /**
     Synchronize dose data with the remote data service.

     - Parameter stored: The stored dose data to synchronize.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func synchronizeDoseData(_ stored: [DoseEntry], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of glucose data to synchronize with the remote data service.
    var glucoseDataLimit: Int { get }

    /**
     Synchronize glucose data with the remote data service.

     - Parameter stored: The stored glucose data to synchronize.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func synchronizeGlucoseData(_ stored: [StoredGlucoseSample], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of pump event data to synchronize with the remote data service.
    var pumpEventDataLimit: Int { get }

    /**
     Synchronize pump event data with the remote data service.

     - Parameter stored: The stored pump event data to synchronize.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func synchronizePumpEventData(_ stored: [PersistedPumpEvent], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of settings data to synchronize with the remote data service.
    var settingsDataLimit: Int { get }

    /**
     Synchronize settings data with the remote data service.

     - Parameter stored: The stored settings data to synchronize.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func synchronizeSettingsData(_ stored: [StoredSettings], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of status data to synchronize with the remote data service.
    var statusDataLimit: Int { get }

    /**
     Synchronize status data with the remote data service.

     - Parameter stored: The stored status data to synchronize.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func synchronizeStatusData(_ stored: [StoredStatus], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

}

public extension RemoteDataService {

    var carbDataLimit: Int { return Int.max }

    var doseDataLimit: Int { return Int.max }

    var glucoseDataLimit: Int { return Int.max }

    var pumpEventDataLimit: Int { return Int.max }

    var settingsDataLimit: Int { return Int.max }

    var statusDataLimit: Int { return Int.max }

}
