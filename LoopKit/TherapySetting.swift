//
//  TherapySetting.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

public enum TherapySetting: Int {
    case glucoseTargetRange
    case correctionRangeOverrides
    case suspendThreshold
    case basalRate
    case deliveryLimits
    case insulinModel
    case carbRatio
    case insulinSensitivity
    case none
}

public extension TherapySetting {
    
    var descriptiveText: String {
        switch self {
        case .glucoseTargetRange:
            <#code#>
        case .correctionRangeOverrides:
            <#code#>
        case .suspendThreshold:
            <#code#>
        case .basalRate:
            <#code#>
        case .deliveryLimits:
            <#code#>
        case .insulinModel:
            <#code#>
        case .carbRatio:
            <#code#>
        case .insulinSensitivity:
            <#code#>
        case .none:
            <#code#>
        }
    }
}
