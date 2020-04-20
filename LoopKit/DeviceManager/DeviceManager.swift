//
//  DeviceManager.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import UserNotifications

public protocol DeviceManagerDelegate: DeviceAlertPresenter {
    func deviceManager(_ manager: DeviceManager, logEventForDeviceIdentifier deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)?)
}

public protocol DeviceManager: CustomDebugStringConvertible, DeviceAlertResponder {
    typealias RawStateValue = [String: Any]

    /// The identifier of the manager. This should be unique
    static var managerIdentifier: String { get }

    /// A title describing this type of manager
    static var localizedTitle: String { get }

    /// A title describing this manager
    var localizedTitle: String { get }

    /// The queue on which delegate methods are called
    /// Setting to nil resets to a default provided by the manager
    var delegateQueue: DispatchQueue! { get set }
    
    /// Initializes the manager with its previously-saved state
    ///
    /// Return nil if the saved state is invalid to prevent restoration
    ///
    /// - Parameter rawState: The last state
    init?(rawState: RawStateValue)

    /// The current, serializable state of the manager
    var rawState: RawStateValue { get }
}


public extension DeviceManager {
    var localizedTitle: String {
        return type(of: self).localizedTitle
    }
    
    /// Represents a per-device-manager-Type identifier that can uniquely identify a class of this type.
    var managerIdentifier: String {
        return Self.managerIdentifier
    }
}
