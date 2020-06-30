//
//  DeviceStatusProgress.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-30.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol DeviceStatusProgress {
    /// the percent complete of the progress for this device status. Expects a value between 0.0 and 1.0
    var percentComplete: Double { get }

    /// the color to highlight the percent complete
    var color: UIColor { get }
}
