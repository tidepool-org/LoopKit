//
//  GlucoseUnitPublishing.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-01-13.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public protocol GlucoseUnitObserver {
    func glucoseUnitDidChange(_ glucoseUnit: HKUnit)
}

public protocol GlucoseUnitPublisher {
    func addGlucoseUnitObserver(_ observer: GlucoseUnitObserver,
                                       queue: DispatchQueue)

    func removeGlucoseUnitObserver(_ observer: GlucoseUnitObserver)

    func notifyObserversOfGlucoseUnitChange(to glucoseUnit: HKUnit)
}
