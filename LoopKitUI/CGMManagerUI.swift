//
//  CGMManagerUI.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public protocol CGMManagerUI: CGMManager, DeviceManagerUI, PreferredGlucoseUnitObserver {
    /// Create and onboard a new CGM manager.
    ///
    /// - Parameters:
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: Either a conforming view controller to create and onboard the CGM manager, a newly created and onboarded CGM manager, or an error.
    static func setupViewController(colorPalette: LoopUIColorPalette) -> UIResult<UIViewController & CGMManagerCreateNotifying & CGMManagerOnboardNotifying & CompletionNotifying, CGMManagerUI, Error>

    /// Configure settings for an existing CGM manager.
    ///
    /// - Parameters:
    ///     - glucoseUnit: The glucose units to use.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: A view controller to configure an existing CGM manager.
    func settingsViewController(for glucoseUnit: HKUnit, colorPalette: LoopUIColorPalette) -> (UIViewController & CGMManagerOnboardNotifying & PreferredGlucoseUnitObserver & CompletionNotifying)

    /// a message from the cgm that needs to be brought to the user's attention in the status bar
    var cgmStatusHighlight: DeviceStatusHighlight? { get }

    /// the completed percent of the progress bar to display in the status bar
    var cgmLifecycleProgress: DeviceLifecycleProgress? { get }

    /// gets the range category of a glucose sample using the CGM manager managed glucose thresholds
    func glucoseRangeCategory(for glucose: GlucoseSampleValue) -> GlucoseRangeCategory?
}

extension CGMManagerUI {
    public func glucoseRangeCategory(for glucose: GlucoseSampleValue) -> GlucoseRangeCategory? {
        return nil
    }

    /// When conformance to the PreferredGlucoseUnitObserver is desired, use this function to be notified when the user preferred glucose unit changes
    public func preferredGlucoseUnitDidChange(to preferredGlucoseUnit: HKUnit) {
        // optional
    }
}

public protocol CGMManagerCreateDelegate: AnyObject {
    /// Informs the delegate that the specified cgm manager was created.
    ///
    /// - Parameters:
    ///     - cgmManager: The cgm manager created.
    func cgmManagerCreateNotifying(_ notifying: CGMManagerCreateNotifying, didCreateCGMManager cgmManager: CGMManagerUI)
}

public protocol CGMManagerCreateNotifying {
    /// Delegate to notify about cgm manager creation.
    var cgmManagerCreateDelegate: CGMManagerCreateDelegate? { get set }
}

public protocol CGMManagerOnboardDelegate: AnyObject {
    /// Informs the delegate that the specified cgm manager was onboarded.
    ///
    /// - Parameters:
    ///     - cgmManager: The cgm manager onboarded.
    func cgmManagerOnboardNotifying(_ notifying: CGMManagerOnboardNotifying, didOnboardCGMManager cgmManager: CGMManagerUI)
}

public protocol CGMManagerOnboardNotifying {
    /// Delegate to notify about cgm manager onboarding.
    var cgmManagerOnboardDelegate: CGMManagerOnboardDelegate? { get set }
}
