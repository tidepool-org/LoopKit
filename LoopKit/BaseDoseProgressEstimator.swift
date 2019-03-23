//
//  BaseDoseProgressEstimator.swift
//  LoopKit
//
//  Created by Pete Schwamb on 3/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


open class BaseDoseProgressEstimator: DoseProgressEstimator {

    public var timer: Timer?

    private var lock = UnfairLock()

    private var observers = WeakSet<DoseProgressObserver>()

    public init() {}

    open var progress: DoseProgress {
        fatalError("progress must be implemented in subclasse")
    }

    public func addObserver(_ observer: DoseProgressObserver) {
        lock.locked {
            let firstObserver = observers.isEmpty
            observers.insert(observer)
            if firstObserver {
                start(on: RunLoop.main)
            }
        }
    }

    public func removeObserver(_ observer: DoseProgressObserver) {
        lock.locked {
            observers.remove(observer)
            if observers.isEmpty {
                stop()
            }
        }
    }

    public func notify() {
        let observersCopy = lock.locked { () -> WeakSet<DoseProgressObserver> in
            return observers
        }

        for observer in observersCopy {
            observer.doseProgressEstimatorHasNewEstimate(self)
        }
    }

    func start(on runLoop: RunLoop) {
        guard self.timer == nil else {
            return
        }
        let timer = createTimer()
        runLoop.add(timer, forMode: .default)
        self.timer = timer
    }

    open func createTimer() -> Timer {
        fatalError("createTimer must be been implemented in subclasse")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
