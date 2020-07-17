//
//  GlucoseValueType+Color.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-22.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

extension GlucoseValueType {
    public var glucoseColor: UIColor {
        switch self {
        case .normal, .high:
            return .label
        case .low, .urgentLow, .belowRange:
            return .critical
        case .aboveRange:
            return .warning
        }
    }
    
    public var trendColor: UIColor {
        switch self {
        case .normal:
            return .glucose
        case .urgentLow, .low, .belowRange:
            return .critical
        case .high, .aboveRange:
            return .warning
        }
    }
}
