//
//  MockCGMManagerSettingsNavigationController.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2021-01-13.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKitUI

final class MockCGMManagerSettingsNavigationController: SettingsNavigationViewController, GlucoseUnitObserver {

    private var rootViewController: MockCGMManagerSettingsViewController

    init(rootViewController: MockCGMManagerSettingsViewController) {
        self.rootViewController = rootViewController
        super.init(rootViewController: rootViewController)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func glucoseUnitDidChange(_ glucoseUnit: HKUnit) {
        rootViewController.glucoseUnitDidChange(glucoseUnit)
    }
}
