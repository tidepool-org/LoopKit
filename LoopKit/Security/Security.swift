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

public protocol Security: AnyObject {
    /// The unique identifier of this type of security.
    static var identifier: String { get }

    /// A security plugin may need backing of a service (e.g., device check app attestation).  This callback allows a security to reference the needed service(s).
    /// It is called once during app initialization after a security are initialized and again as new securities are added and initialized.
    func initializationComplete(for services: [Service])
}

public extension Security {
    var identifier: String { return type(of: self).identifier }
}
