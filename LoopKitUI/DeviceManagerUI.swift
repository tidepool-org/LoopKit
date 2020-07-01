//
//  DeviceManagerUI.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 6/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

public protocol DeviceManagerUI: DeviceManager {
    /// An image representing this device (staticly available for presenting before the user chooses to set it up)
    static var smallImage: UIImage? { get }
    /// An image representing a device configuration after it is set up
    var smallImage: UIImage? { get }
}

public extension DeviceManagerUI {
    static var smallImage: UIImage? { return nil }
}

public extension DeviceManagerUI {
    var smallImage: UIImage? {
        return type(of: self).smallImage
    }
}
