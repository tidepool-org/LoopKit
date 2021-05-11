//
//  GlucoseRangeCategory.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-23.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum GlucoseRangeCategoryColor: String {
    case label, critical, warning, glucose
}

public enum GlucoseRangeCategory: Int, CaseIterable {
    case belowRange
    case urgentLow
    case low
    case normal
    case high
    case aboveRange
}

extension GlucoseRangeCategory {
    public var glucoseCategoryColor: GlucoseRangeCategoryColor {
        switch self {
        case .normal, .high, .low:
            return .label
        case .urgentLow, .belowRange:
            return .critical
        case .aboveRange:
            return .warning
        }
    }
    
    public var trendCategoryColor: GlucoseRangeCategoryColor {
        switch self {
        case .normal:
            return .glucose
        case .urgentLow, .belowRange:
            return .critical
        case .low, .high, .aboveRange:
            return .warning
        }
    }
}
