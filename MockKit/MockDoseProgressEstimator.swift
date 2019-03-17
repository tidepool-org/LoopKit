//
//  MockDoseProgressEstimator.swift
//  MockKit
//
//  Created by Pete Schwamb on 3/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

class MockDoseProgressEstimator: DoseProgressEstimator {
    weak var delegate: DoseProgressEstimatorDelegate?

    public let dose: DoseEntry

    private var timer: Timer?

    var estimatedDeliveredUnits: Double {
        let elapsed = -dose.startDate.timeIntervalSinceNow
        let duration = dose.endDate.timeIntervalSince(dose.startDate)
        let percentProgress = min(elapsed / duration, 1)
        let delivered = round(percentProgress * dose.units * 20) / 20
        return delivered
    }

    init(dose: DoseEntry) {
        self.dose = dose
    }

    func start(on runLoop: RunLoop) {
        let timeSinceStart = dose.startDate.timeIntervalSinceNow
        let timeBetweenPulses: TimeInterval
        switch dose.type {
        case .bolus:
            timeBetweenPulses = TimeInterval(2)
        case .basal, .tempBasal:
            timeBetweenPulses = 0.05 / dose.unitsPerHour
        default:
            fatalError("Can only estimate progress on basal rates or boluses.")
        }
        let delayUntilNextPulse = timeBetweenPulses - timeSinceStart.remainder(dividingBy: timeBetweenPulses)
        let timer = Timer(fire: Date() + delayUntilNextPulse, interval: timeBetweenPulses, repeats: true) { [weak self] _  in
            if let self = self {
                self.delegate?.doseProgressEstimatorHasNewEstimate(self)
            }
        }
        runLoop.add(timer, forMode: .default)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
    }
}
