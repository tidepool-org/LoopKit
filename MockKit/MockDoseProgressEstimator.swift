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


    public let dose: DoseEntry

    private var observers = WeakSet<DoseProgressObserver>()

    private var timer: Timer?

    private var lock = os_unfair_lock()

    var progress: DoseProgress {
        let elapsed = -dose.startDate.timeIntervalSinceNow
        let duration = dose.endDate.timeIntervalSince(dose.startDate)
        let percentProgress = min(elapsed / duration, 1)
        let delivered = round(percentProgress * dose.units * 20) / 20
        return DoseProgress(deliveredUnits: delivered, percentComplete: delivered / dose.units)
    }

    init(dose: DoseEntry) {
        self.dose = dose
    }

    func addObserver(_ observer: DoseProgressObserver) {
        os_unfair_lock_lock(&lock)
        defer {
            os_unfair_lock_unlock(&lock)
        }
        let firstObserver = observers.isEmpty
        observers.insert(observer)
        if firstObserver {
            start(on: RunLoop.main)
        }
    }

    func removeObserver(_ observer: DoseProgressObserver) {
        os_unfair_lock_lock(&lock)
        defer {
            os_unfair_lock_unlock(&lock)
        }
        observers.remove(observer)
        if observers.isEmpty {
            stop()
        }
    }

    func notify() {
        os_unfair_lock_lock(&lock)
        let observersCopy = observers
        os_unfair_lock_unlock(&lock)

        for observer in observersCopy {
            observer.doseProgressEstimatorHasNewEstimate(self)
        }
    }

    func start(on runLoop: RunLoop) {
        guard self.timer == nil else {
            return
        }
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
                self.notify()
            }
        }
        runLoop.add(timer, forMode: .default)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
