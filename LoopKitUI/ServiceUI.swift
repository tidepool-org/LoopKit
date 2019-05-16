//
//  ServiceUI.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit


public protocol ServiceUI: Service {

    /// Provides a view controller to create and configure a new service, if needed.
    ///
    /// - Returns: A view controller to create and configure a new service.
    static func setupViewController() -> (UIViewController & ServiceSetupNotifying & CompletionNotifying)?

    /// Provides a view controller to configure an existing service.
    ///
    /// - Returns: A view controller to configure an existing service.
    func settingsViewController() -> (UIViewController & CompletionNotifying)

}


public protocol ServiceSetupNotifying {

    var serviceSetupDelegate: ServiceSetupDelegate? { get set }

}


public protocol ServiceSetupDelegate: class {

    /// Notifies the delegate that a new service was created and configured.
    ///
    /// - Parameters:
    ///     - serviceSetupNotifying: The service setup notifying.
    ///     - service: The created and configured service.
    func serviceSetupNotifyingDidSetupService(_ serviceSetupNotifying: ServiceSetupNotifying, service: Service)

}
