//
//  CGMManagerUI.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public struct CGMManagerDescriptor {
    public let identifier: String
    public let localizedTitle: String

    public init(identifier: String, localizedTitle: String) {
        self.identifier = identifier
        self.localizedTitle = localizedTitle
    }
}

public protocol DeviceStatusIndicator {
    /// a message from the cgm that needs to be brought to the user's attention in the status bar
    var cgmStatusHighlight: DeviceStatusHighlight? { get }

    /// the completed percent of the progress bar to display in the status bar
    var cgmLifecycleProgress: DeviceLifecycleProgress? { get }

    /// gets the range category of a glucose sample using the CGM manager managed glucose thresholds
    func glucoseRangeCategory(for glucose: GlucoseSampleValue) -> GlucoseRangeCategory?
}

public protocol CGMManagerUI: CGMManager, DeviceManagerUI, PreferredGlucoseUnitObserver, DeviceStatusIndicator {
    /// Create and onboard a new CGM manager.
    ///
    /// - Parameters:
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: Either a conforming view controller to create and onboard the CGM manager or a newly created and onboarded CGM manager.
    static func setupViewController(colorPalette: LoopUIColorPalette) -> SetupUIResult<UIViewController & CGMManagerCreateNotifying & CGMManagerOnboardNotifying & CompletionNotifying, CGMManagerUI>

    /// Configure settings for an existing CGM manager.
    ///
    /// - Parameters:
    ///     - preferredGlucoseUnit: The preferred glucose units to use.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: A view controller to configure an existing CGM manager.
    func settingsViewController(for preferredGlucoseUnit: HKUnit, colorPalette: LoopUIColorPalette) -> (UIViewController & CGMManagerOnboardNotifying & PreferredGlucoseUnitObserver & CompletionNotifying)

    /// a badge from the cgm that needs to be brought to the user's attention in the status bar
    var cgmStatusBadge: DeviceStatusBadge? { get }
    
}

public protocol CGMManagerUI: CGMManager, DeviceManagerUI, PreferredGlucoseUnitObserver, DeviceStatusIndicator {
    /// Provides a view controller for setting up and configuring the manager if needed.
    ///
    /// If this method returns nil, it's expected that `init?(rawState: [:])` creates a non-nil manager
    static func setupViewController(glucoseTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CGMManagerSetupViewController & CompletionNotifying)?

    func settingsViewController(for glucoseUnit: HKUnit, glucoseTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CompletionNotifying & PreferredGlucoseUnitObserver)
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
    func cgmManagerCreateNotifying(didCreateCGMManager cgmManager: CGMManagerUI)
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
    func cgmManagerOnboardNotifying(didOnboardCGMManager cgmManager: CGMManagerUI)
}

public protocol CGMManagerOnboardNotifying {
    /// Delegate to notify about cgm manager onboarding.
    var cgmManagerOnboardDelegate: CGMManagerOnboardDelegate? { get set }
}
