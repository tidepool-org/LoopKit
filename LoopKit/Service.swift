//
//  Service.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

public struct ServiceDescriptor {
    public let identifier: String
    public let localizedTitle: String

    public init(identifier: String, localizedTitle: String) {
        self.identifier = identifier
        self.localizedTitle = localizedTitle
    }
}

public protocol ServiceDelegate: AnyObject {
    /// Informs the delegate that the state of the specified service was updated and the delegate should persist the service. May
    /// be invoked prior to the service completing setup.
    ///
    /// - Parameters:
    ///     - service: The service that updated state.
    func serviceDidUpdateState(_ service: Service)

    /// Informs the delegate that the service was deleted.
    ///
    /// - Parameters:
    ///     - service: The service that was deleted.
    func serviceWasDeleted(_ service: Service)
}

public protocol Service: AnyObject {
    typealias RawStateValue = [String: Any]

    /// The unique identifier of this type of service.
    static var serviceIdentifier: String { get }

    /// The localized title of this type of service.
    static var localizedTitle: String { get }

    /// The delegate to notify of service updates.
    var serviceDelegate: ServiceDelegate? { get set }

    /// Initializes the service with the previously-serialized state.
    ///
    /// - Parameters:
    ///     - rawState: The previously-serialized state of the service.
    init?(rawState: RawStateValue)

    /// The current, serializable state of the service.
    var rawState: RawStateValue { get }

    /// Is the service onboarded and ready for use?
    var isOnboarded: Bool { get }

    /// Delete the service.
    func delete()
}

public extension Service {
    var serviceIdentifier: String { return type(of: self).serviceIdentifier }
    var localizedTitle: String { return type(of: self).localizedTitle }
}
