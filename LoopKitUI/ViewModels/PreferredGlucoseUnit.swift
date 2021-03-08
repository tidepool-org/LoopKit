//
//  PreferredGlucoseUnit.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-08.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public class PreferredGlucoseUnit: ObservableObject {
    @Published public private(set) var unit: HKUnit

    public init(unit: HKUnit) {
        self.unit = unit
    }
}

extension PreferredGlucoseUnit: PreferredGlucoseUnitObserver {
    public func preferredGlucoseUnitDidChange(to preferredGlucoseUnit: HKUnit) {
        self.unit = preferredGlucoseUnit
    }
}
