//
//  LoopAlgorithmOutput.swift
//
//
//  Created by Pete Schwamb on 10/13/23.
//

import Foundation
import HealthKit

public struct LoopAlgorithmOutput {
    public var recommendationResult: Result<LoopAlgorithmDoseRecommendation,Error>
    public var predictedGlucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects
    public var dosesRelativeToBasal: [DoseEntry]
    public var activeInsulin: Double?
    public var activeCarbs: Double?
}
