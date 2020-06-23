//
//  DeviceManagerStatusReport.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-23.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol DeviceManagerStatusReport {
    /// a message from the device that needs to be brought to the user's attention
    var deviceMessage: DeviceMessage? { get }

    /// indication if the progress bar should be displayed
    var displayProgress: Bool { get }

    /// the completed percent of the progress bar
    var progressPercentCompleted: Double? { get }
}

public protocol DeviceMessage: Codable {
    /// a localized message from the device
    var message: String { get }

    /// the state of the message that directs how the message is presented (e.g., icon and color)
    var messageState: DeviceMessageState { get }
}
