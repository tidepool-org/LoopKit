//
//  ServiceUI.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public protocol ServiceUI: Service {
    /// The image for this type of service.
    static var image: UIImage? { get }

    /// Create and onboard a new service.
    ///
    /// - Parameters:
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: Either a conforming view controller to create and onboard the service, a newly created and onboarded service, or an error.
    static func setupViewController(colorPalette: LoopUIColorPalette) -> UIResult<UIViewController & ServiceCreateNotifying & ServiceOnboardNotifying & CompletionNotifying, ServiceUI, Error>

    /// Configure settings for an existing service.
    ///
    /// - Parameters:
    ///     - glucoseUnit: The glucose units to use.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: A view controller to configure an existing service.
    func settingsViewController(colorPalette: LoopUIColorPalette) -> (UIViewController & ServiceOnboardNotifying & CompletionNotifying)
}

public extension ServiceUI {
    var image: UIImage? { return type(of: self).image }
}

public protocol ServiceCreateDelegate: AnyObject {
    /// Informs the delegate that the specified service was created.
    ///
    /// - Parameters:
    ///     - service: The service created.
    func serviceCreateNotifying(_ notifying: ServiceCreateNotifying, didCreateService service: Service)
}

public protocol ServiceCreateNotifying {
    /// Delegate to notify about service creation.
    var serviceCreateDelegate: ServiceCreateDelegate? { get set }
}

public protocol ServiceOnboardDelegate: AnyObject {
    /// Informs the delegate that the specified service was onboarded.
    ///
    /// - Parameters:
    ///     - service: The service onboarded.
    func serviceOnboardNotifying(_ notifying: ServiceOnboardNotifying, didOnboardService service: Service)
}

public protocol ServiceOnboardNotifying {
    /// Delegate to notify about service onboarding.
    var serviceOnboardDelegate: ServiceOnboardDelegate? { get set }
}
