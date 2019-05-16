//
//  Service.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


public protocol ServiceDelegate: AnyObject {

    /// Informs the delegate that the specified service was updated.
    ///
    /// - Parameters:
    ///     - service: The service updated.
    func serviceUpdated(_ service: Service)

    /// Informs the delegate that the specified service was deleted.
    ///
    /// - Parameters:
    ///     - service: The service deleted.
    func serviceDeleted(_ service: Service)

}


public protocol Service: DeviceManager {

    var serviceDelegate: ServiceDelegate? { get set }

    /// Is the service complete?
    var isComplete: Bool { get }

    /// Verify the service. Send any error to completion closure.
    ///
    /// - Parameters:
    ///     - completion: A closure called once upon completion with any error.
    func verify(completion: @escaping (Error?) -> Void)

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

    var isComplete: Bool { return true }

    func verify(completion: @escaping (Error?) -> Void) {
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
