//
//  DisplayGlucoseUnitObservable.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-10.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import Combine
import HealthKit

public class DisplayGlucoseUnitObservable: ObservableObject {
    @Published public private(set) var displayGlucoseUnit: HKUnit {
        didSet {
            updatePublisher.send()
        }
    }

    public let updatePublisher = PassthroughSubject<Void, Never>()

    public init(displayGlucoseUnit: HKUnit) {
        self.displayGlucoseUnit = displayGlucoseUnit
    }
}

extension DisplayGlucoseUnitObservable: DisplayGlucoseUnitObserver {
    public func displayGlucoseUnitDidChange(to displayGlucoseUnit: HKUnit) {
        self.displayGlucoseUnit = displayGlucoseUnit
    }
}
