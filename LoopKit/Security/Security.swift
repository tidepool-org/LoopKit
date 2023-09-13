//
//  Security.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2023-09-05.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol SecurityDelegate: AnyObject {
    /// Informs the delegate that the state of the specified security was updated and the delegate should persist the security. May
    /// be invoked prior to the security completing setup.
    ///
    /// - Parameters:
    ///     - security: The security that updated state.
    func securityDidUpdateState(_ security: Security)
}

public protocol SecurityPlugin {
    var securityType: Security.Type? { get }
}

public protocol SecurityProvider {
    /// The security with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the security
    /// - Returns: Either a security with matching identifier or nil.
    func security(withIdentifier identifier: String) -> Security?
}

public protocol Security: Pluggable {
    typealias RawStateValue = [String: Any]
    
    /// The delegate to notify of security updates.
    var delegate: SecurityDelegate? { get set }
    
    /// Initializes the security with the default state.
    init()
    
    /// Initializes the security with the previously-serialized state.
    ///
    /// - Parameters:
    ///     - rawState: The previously-serialized state of the security.
    init?(rawState: RawStateValue)

    /// The current, serializable state of the security.
    var rawState: RawStateValue { get }
}
