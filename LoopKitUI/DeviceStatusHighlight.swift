//
//  DeviceStatusHighlight.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-23.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol DeviceStatusHighlight {
    /// a localized message from the device
    var message: String { get }

    /// the icon related to the message
    var icon: UIImage { get }
    
    /// the color of the highlight
    var color: UIColor { get }
}
