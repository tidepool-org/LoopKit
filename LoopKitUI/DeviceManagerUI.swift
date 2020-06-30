//
//  DeviceManagerUI.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 6/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

public protocol DeviceManagerUI {
    /// An image representing the device configuration
    static var image: UIImage? { get }
    /// A localized name of the device to display to the user
    static var name: String { get }
    /// A localized detail description of the device to display to the user
    static var details: String { get }
}

public extension DeviceManagerUI {
    static var image: UIImage? { return nil }
    static var name: String { return "" }
    static var details: String { return "" }
}

public extension DeviceManagerUI {
    var smallImage: UIImage? {
        return type(of: self).image
    }
}
