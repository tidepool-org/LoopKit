//
//  VersionCheckUI.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 10/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public protocol VersionCheckUI: AnyObject {
    
    func setAlertIssuer(alertIssuer: AlertIssuer?)
    
    /// Provides screen for software update UI.
    ///
    /// - Returns: A view that will be opened when a software update is available from this service.
    func softwareUpdateView(guidanceColors: GuidanceColors,
                            bundleIdentifier: String,
                            currentVersion: String,
                            openAppStoreHook: (() -> Void)?
    ) -> AnyView?
}
