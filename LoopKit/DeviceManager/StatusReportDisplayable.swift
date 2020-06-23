//
//  StatusReportDisplayable.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-23.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol StatusReportDisplayable {
    /// a localized string describing a status report message that needs to be brought to the user's attention
    var message: String? { get }

    /// the type of the message that directs how the message is presented (e.g., icon and color)
    var messageType: MessageType? { get }

    /// indication if the progress bar should be displayed
    var displayProgress: Bool { get }

    /// the completed percent of the progress bar
    var progressPercentCompleted: Double? { get }
}
