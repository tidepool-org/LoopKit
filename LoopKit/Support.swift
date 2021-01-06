//
//  Support.swift
//  LoopKit
//
//  Created by Darin Krauss on 12/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

public protocol Support: AnyObject {
    /// The unique identifier of this type of support.
    var supportIdentifier: String { get }

    /// Initializes the support.
    init()
}
