//
//  PreferredDisplayGlucoseUnitObservable.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-08.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public class PreferredDisplayGlucoseUnitObservable: ObservableObject {
    @Published public private(set) var preferredGlucoseUnit: HKUnit

    public init(preferredGlucoseUnit: HKUnit) {
        self.preferredGlucoseUnit = preferredGlucoseUnit
    }
}

extension PreferredDisplayGlucoseUnitObservable: PreferredGlucoseUnitObserver {
    public func preferredGlucoseUnitDidChange(to preferredGlucoseUnit: HKUnit) {
        self.preferredGlucoseUnit = preferredGlucoseUnit
    }
}
