//
//  MockCGMManager+UI.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/23/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import SwiftUI
import HealthKit
import LoopKit
import LoopKitUI
import MockKit


extension MockCGMManager: CGMManagerUI {

    public var smallImage: UIImage? { return UIImage(named: "CGM Simulator", in: Bundle(for: MockCGMManagerSettingsViewController.self), compatibleWith: nil) }

    public static func setupViewController(colorPalette: LoopUIColorPalette) -> UIResult<UIViewController & CGMManagerCreateNotifying & CGMManagerOnboardNotifying & CompletionNotifying, CGMManagerUI, Error> {
        return .success(MockCGMManager())
    }

    public func settingsViewController(for glucoseUnit: HKUnit, colorPalette: LoopUIColorPalette) -> (UIViewController & CGMManagerOnboardNotifying & PreferredGlucoseUnitObserver & CompletionNotifying) {
        let settings = MockCGMManagerSettingsViewController(cgmManager: self, glucoseUnit: glucoseUnit)
        let nav = CGMManagerSettingsNavigationViewController(rootViewController: settings)
        return nav
    }

    public var cgmStatusHighlight: DeviceStatusHighlight? {
        return self.mockSensorState.cgmStatusHighlight
    }

    // TODO Placeholder. This functionality will come with LOOP-1293
    public var cgmLifecycleProgress: DeviceLifecycleProgress? {
        return self.mockSensorState.cgmLifecycleProgress
    }
}
