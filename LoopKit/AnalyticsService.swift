//
//  AnalyticsService.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/11/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol AnalyticsService {

    /// The unique identifier of this type of service.
    var serviceIdentifier: String { get }

    func recordAnalyticsEvent(_ name: String, withProperties properties: [AnyHashable: Any]?, outOfSession: Bool)

}
