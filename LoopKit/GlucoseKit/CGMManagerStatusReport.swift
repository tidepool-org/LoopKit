//
//  CGMManagerStatusReport.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-23.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol CGMManagerStatusReport: DeviceManagerStatusReport, SensorDisplayable {
    /// enumerates the glucose value type (e.g., normal, low, high)
    var glucoseValueType: GlucoseValueType? { get }
}
