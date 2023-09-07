//
//  BolusActivationType.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2023-09-07.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

public enum BolusActivationType: String, Codable {
    case manualNoRecommendation
    case manualRecommendationAccepted
    case manualRecommendationChanged
    case automatic

    public var isAutomatic: Bool {
        self == .automatic
    }

    static public func activationTypeFor(recommendedAmount: Double?, bolusAmount: Double) -> BolusActivationType {
        guard let recommendedAmount = recommendedAmount else { return .manualNoRecommendation }
        return recommendedAmount =~ bolusAmount ? .manualRecommendationAccepted : .manualRecommendationChanged
    }
}
