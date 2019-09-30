//
//  Service.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

public protocol Service: AnyObject {

    typealias RawStateValue = [String: Any]

    /// The unique identifier of this type of service.
    static var serviceIdentifier: String { get }

    /// The localized title of this type of service.
    static var localizedTitle: String { get }

    /// The localized title of this service.
    var localizedTitle: String { get }

    /// Initializes the service with the previously-serialized state.
    ///
    /// - Parameters:
    ///     - rawState: The previously-serialized state of the service.
    init?(rawState: RawStateValue)

    /// The current, serializable state of the service.
    var rawState: RawStateValue { get }

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

    var serviceIdentifier: String { return type(of: self).serviceIdentifier }

    var localizedTitle: String { return type(of: self).localizedTitle }

    var hasConfiguration: Bool { return true }

    func verifyConfiguration(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    func completeCreate() {}

    func completeUpdate() {}

    func completeDelete() {}

}
