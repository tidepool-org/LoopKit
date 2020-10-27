//
//  DoseType.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation


/// A general set of ways insulin can be delivered by a pump
public enum DoseType: String, CaseIterable {
    case basal
    case bolus
    case resume
    case suspend
    case tempBasal
    
    var localizedDescription: String {
        switch self {
        case .basal:
            return NSLocalizedString("Basal", comment: "localized term for basal dose type")
        case .bolus:
            return NSLocalizedString("Bolus", comment: "localized term for bolus dose type")
        case .tempBasal:
            return NSLocalizedString("Temp Basal", comment: "localized term for temp basal dose type")
        case .suspend:
            return NSLocalizedString("Suspended", comment: "localized term for suspend dose type")
        case .resume:
            return NSLocalizedString("Resumed", comment: "localized term for resume dose type")
        }
    }
}

extension DoseType: Codable {}

/// Compatibility transform to PumpEventType
extension DoseType {
    public init?(pumpEventType: PumpEventType) {
        switch pumpEventType {
        case .basal:
            self = .basal
        case .bolus:
            self = .bolus
        case .resume:
            self = .resume
        case .suspend:
            self = .suspend
        case .tempBasal:
            self = .tempBasal
        case .alarm, .alarmClear, .prime, .rewind:
            return nil
        }
    }

    public var pumpEventType: PumpEventType? {
        switch self {
        case .basal:
            return .basal
        case .bolus:
            return .bolus
        case .resume:
            return .resume
        case .suspend:
            return .suspend
        case .tempBasal:
            return .tempBasal
        }
    }
}
