//
//  Onboarding.swift
//  LoopKit
//
//  Created by Darin Krauss on 12/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

public protocol Onboarding: AnyObject {
    /// The unique identifier of this type of onboarding.
    var onboardingIdentifier: String { get }

    /// Initializes the onboarding.
    init()
}
