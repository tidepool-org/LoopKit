//
//  PumpManagerUI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import SwiftUI
import LoopKit

public struct PumpManagerSettings {
    public var maxBasalRateUnitsPerHour: Double?
    public var maxBolusUnits: Double?
    public var basalSchedule: BasalRateSchedule?

    public init(maxBasalRateUnitsPerHour: Double?, maxBolusUnits: Double?, basalSchedule: BasalRateSchedule?) {
        self.maxBasalRateUnitsPerHour = maxBasalRateUnitsPerHour
        self.maxBolusUnits = maxBolusUnits
        self.basalSchedule = basalSchedule
    }
}

public protocol PumpManagerUI: DeviceManagerUI, PumpManager, DeliveryLimitSettingsTableViewControllerSyncSource, BasalScheduleTableViewControllerSyncSource {
    /// Create and onboard a new pump manager.
    ///
    /// - Parameters:
    ///     - settings: Settings used to configure the pump manager.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: Either a conforming view controller to create and onboard the pump manager, a newly created and onboarded pump manager, or an error.
    static func setupViewController(initialSettings settings: PumpManagerSettings, colorPalette: LoopUIColorPalette) -> UIResult<UIViewController & PumpManagerCreateNotifying & PumpManagerOnboardNotifying & CompletionNotifying, PumpManagerUI, Error>

    /// Configure settings for an existing pump manager.
    ///
    /// - Parameters:
    ///     - glucoseUnit: The glucose units to use.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: A view controller to configure an existing pump manager.
    func settingsViewController(colorPalette: LoopUIColorPalette) -> (UIViewController & PumpManagerOnboardNotifying & CompletionNotifying)

    // View for recovering from delivery uncertainty
    func deliveryUncertaintyRecoveryViewController(colorPalette: LoopUIColorPalette) -> (UIViewController & CompletionNotifying)

    // Returns a class that can provide HUD views
    func hudProvider(colorPalette: LoopUIColorPalette) -> HUDProvider?

    // Instantiates HUD view (typically reservoir volume) from the raw state returned by hudViewRawState
    static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> LevelHUDView?
}

public protocol PumpManagerCreateDelegate: AnyObject {
    /// Informs the delegate that the specified pump manager was created.
    ///
    /// - Parameters:
    ///     - pumpManager: The pump manager created.
    func pumpManagerCreateNotifying(_ notifying: PumpManagerCreateNotifying, didCreatePumpManager pumpManager: PumpManagerUI)
}

public protocol PumpManagerCreateNotifying {
    /// Delegate to notify about pump manager creation.
    var pumpManagerCreateDelegate: PumpManagerCreateDelegate? { get set }
}

public protocol PumpManagerOnboardDelegate: AnyObject {
    /// Informs the delegate that the specified pump manager was onboarded.
    ///
    /// - Parameters:
    ///     - pumpManager: The pump manager onboarded.
    func pumpManagerOnboardNotifying(_ notifying: PumpManagerOnboardNotifying, didOnboardPumpManager pumpManager: PumpManagerUI, withFinalSettings settings: PumpManagerSettings)
}

public protocol PumpManagerOnboardNotifying {
    /// Delegate to notify about pump manager onboarding.
    var pumpManagerOnboardDelegate: PumpManagerOnboardDelegate? { get set }
}
