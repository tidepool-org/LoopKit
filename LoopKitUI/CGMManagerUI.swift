//
//  CGMManagerUI.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public protocol CGMManagerUI: CGMManager, DeviceManagerUI {
    /// Provides a view controller for setting up and configuring the manager if needed.
    ///
    /// If this method returns nil, it's expected that `init?(rawState: [:])` creates a non-nil manager
    static func setupViewController(glucoseTintColor: Color, guardrailColors: GuardrailColors) -> (UIViewController & CGMManagerSetupViewController & CompletionNotifying)?

    func settingsViewController(for glucoseUnit: HKUnit, glucoseTintColor: Color, guardrailColors: GuardrailColors) -> (UIViewController & CompletionNotifying)
    
    /// a message from the cgm that needs to be brought to the user's attention in the status bar
    var cgmStatusHighlight: DeviceStatusHighlight? { get }
    
    /// the completed percent of the progress bar to display in the status bar
    var cgmLifecycleProgress: DeviceLifecycleProgress? { get }
}

public protocol CGMManagerSetupViewController {
    var setupDelegate: CGMManagerSetupViewControllerDelegate? { get set }
}


public protocol CGMManagerSetupViewControllerDelegate: class {
    func cgmManagerSetupViewController(_ cgmManagerSetupViewController: CGMManagerSetupViewController, didSetUpCGMManager cgmManager: CGMManagerUI)
}
