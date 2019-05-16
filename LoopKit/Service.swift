//
//  Service.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


public protocol ServiceDelegate: AnyObject {

    /// Informs the delegate that the specified service was updated.
    /// An existing service is considered updated when the credentials,
    /// authorization, or any other configuration necessary for the
    /// service are changed. The delegate should respond by writing
    /// the specified service to persistent storage.
    ///
    /// - Parameters:
    ///     - service: The service updated.
    func serviceUpdated(_ service: Service)

    /// Informs the delegate that the specified service was deleted.
    /// The delegate should respond by removing the specified service
    /// from persistent storage.
    ///
    /// - Parameters:
    ///     - service: The service deleted.
    func serviceDeleted(_ service: Service)

}


public protocol Service: DeviceManager {

    var serviceDelegate: ServiceDelegate? { get set }

    /// Does the service have a valid configuration?
    var hasValidConfiguration: Bool { get }

    /// Verify the service configuration. Send any error to completion closure.
    ///
    /// - Parameters:
    ///     - completion: A closure called once upon completion with any error.
    func verifyConfiguration(completion: @escaping (Error?) -> Void)

    /// Informs the service that it was created.
    ///
    /// - Parameters:
    ///     - completion: A closure called once upon completion.
    func notifyCreated(completion: @escaping () -> Void)

    /// Informs the service that it was updated.
    ///
    /// - Parameters:
    ///     - completion: A closure called once upon completion.
    func notifyUpdated(completion: @escaping () -> Void)

    /// Informs the service that it was deleted.
    ///
    /// - Parameters:
    ///     - completion: A closure called once upon completion.
    func notifyDeleted(completion: @escaping () -> Void)

}


public extension Service {

    var hasValidConfiguration: Bool { return true }

    func verifyConfiguration(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    func notifyCreated(completion: @escaping () -> Void) {
        notifyDelegateOfCreation(completion: completion)
    }

    func notifyDelegateOfCreation(completion: @escaping () -> Void) {
        delegateQueue.async {
            completion()
        }
    }

    func notifyUpdated(completion: @escaping () -> Void) {
        notifyDelegateOfUpdation(completion: completion)
    }

    func notifyDelegateOfUpdation(completion: @escaping () -> Void) {
        delegateQueue.async {
            self.serviceDelegate?.serviceUpdated(self)
            completion()
        }
    }

    func notifyDeleted(completion: @escaping () -> Void) {
        notifyDelegateOfDeletion(completion: completion)
    }

    func notifyDelegateOfDeletion(completion: @escaping () -> Void) {
        delegateQueue.async {
            self.serviceDelegate?.serviceDeleted(self)
            completion()
        }
    }

}
