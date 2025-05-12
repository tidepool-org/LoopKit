//
//  TreatmentArrowState.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2025-03-06.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import LoopKit

extension AutomatedTreatmentState {
    public var imageName: String {
        switch self {
        case .neutral: return "arrow.right.square.fill"
        case .increasedInsulin: return "arrow.up.square.fill"
        case .decreasedInsulin, .minimumDelivery: return "arrow.down.square.fill"
        }
    }
}
