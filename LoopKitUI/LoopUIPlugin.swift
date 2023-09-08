//
//  LoopUIPlugin.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 7/24/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

public protocol PumpManagerUIPluginProvider {
    var pumpManagerType: PumpManagerUI.Type? { get }
}

public protocol CGMManagerUIPluginProvider {
    var cgmManagerType: CGMManagerUI.Type? { get }
}

public protocol ServiceUIPluginProvider {
    var serviceType: ServiceUI.Type? { get }
}

public protocol OnboardingUIPluginProvider {
    var onboardingType: OnboardingUI.Type? { get }
}

public protocol SupportUIPluginProvider {
    var support: SupportUI { get }
}
