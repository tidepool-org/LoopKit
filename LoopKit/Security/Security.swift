//
//  Security.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2023-09-05.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol SecurityPlugin {
    var security: Security { get }
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
    func verifyDevice(completion: @escaping (Result<Bool, Error>) -> Void)
    func verifyApp(completion: @escaping (Result<Bool, Error>) -> Void)
}
