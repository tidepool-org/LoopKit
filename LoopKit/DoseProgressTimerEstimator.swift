//
//  DoseProgressTimerEstimator.swift
//  LoopKit
//
//  Created by Pete Schwamb on 3/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


open class DoseProgressTimerEstimator: DoseProgressReporter {
    public var timer: DispatchSourceTimer?

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
                start()
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
            observer.doseProgressReporterDidUpdate(self)
        }
    }

    func start() {
        guard self.timer == nil else {
            return
        }

        let (delay, repeating) = timerParameters()

        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + delay, repeating: repeating)
        timer.setEventHandler(handler: { [weak self] in
            self?.notify()
        })
        self.timer = timer
        timer.resume()
    }

    open func timerParameters() -> (delay: TimeInterval, repeating: TimeInterval) {
        fatalError("timerParameters must be been implemented in subclasse")
    }

    func stop() {
        guard let timer = timer else {
            return
        }

        timer.setEventHandler {}
        timer.cancel()
        self.timer = nil
    }

    deinit {
        stop()
    }
}
