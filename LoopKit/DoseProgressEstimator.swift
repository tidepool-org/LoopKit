//
//  DoseProgressEstimator.swift
//  LoopKit
//
//  Created by Pete Schwamb on 3/12/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol DoseProgressEstimatorDelegate: class {
    func doseProgressEstimatorHasNewEstimate(_ doseProgressEstimator: DoseProgressEstimator)
}

public protocol DoseProgressEstimator: class {
    var delegate: DoseProgressEstimatorDelegate? { get set }

    var dose: DoseEntry { get }

    var estimatedDeliveredUnits: Double { get }

    func start(on runLoop: RunLoop)

    func stop()
}
