//
//  DeviceManagerStatus.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-23.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol DeviceManagerStatus {
    /// a message from the device that needs to be brought to the user's attention
    var specialStatus: DeviceSpecialStatus? { get }

    /// the completed percent of the progress bar to display
    var progressPercentCompleted: Double? { get }
}
