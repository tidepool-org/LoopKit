//
//  Service.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


public protocol ServiceDelegate: AnyObject {

    /// Informs the delegate that the specified service was created.
    /// The delegate should respond by adding the specified service
    /// to persistent storage.
    ///
    /// - Parameters:
    ///     - service: The service created.
    func notifyServiceCreated(_ service: Service)

    /// Informs the delegate that the specified service was updated.
    /// An existing service is considered updated when the credentials,
    /// authorization, or any other configuration necessary for the
    /// service are changed. The delegate should respond by writing
    /// the specified service to persistent storage.
    ///
    /// - Parameters:
    ///     - service: The service updated.
    func notifyServiceUpdated(_ service: Service)

    /// Informs the delegate that the specified service was deleted.
    /// The delegate should respond by removing the specified service
    /// from persistent storage.
    ///
    /// - Parameters:
    ///     - service: The service deleted.
    func notifyServiceDeleted(_ service: Service)

}

public protocol ServiceNotifying: AnyObject {

    /// Delegate to notify about service changes.
    var serviceDelegate: ServiceDelegate? { get set }

}

public protocol Service: DeviceManager {

    /// Does the service have a configuration?
    var hasConfiguration: Bool { get }

    /// Verify the service configuration. Send any error to completion closure.
    ///
    /// - Parameters:
    ///     - completion: A closure called once upon completion with any error.
    func verifyConfiguration(completion: @escaping (Error?) -> Void)

    /// Complete any steps required for creating the service.
    func completeCreate()

    /// Complete any steps required for updating the service.
    func completeUpdate()

    /// Complete any steps required for deleting the service.
    func completeDelete()

}


public extension Service {

    var hasConfiguration: Bool { return true }

    func verifyConfiguration(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    func completeCreate() {}

    func completeUpdate() {}

    func completeDelete() {}

}
