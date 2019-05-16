//
//  TempBasalRecommendation.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


public struct TempBasalRecommendation: Equatable {
    public let unitsPerHour: Double
    public let duration: TimeInterval

    /// A special command which cancels any existing temp basals
    static var cancel: TempBasalRecommendation {
        return self.init(unitsPerHour: 0, duration: 0)
    }

    public init(unitsPerHour: Double, duration: TimeInterval) {
        self.unitsPerHour = unitsPerHour
        self.duration = duration
    }
}


extension TempBasalRecommendation {
    /// Equates the recommended rate with another rate
    ///
    /// - Parameter unitsPerHour: The rate to compare
    /// - Returns: Whether the rates are equal within Double precision
    private func matchesRate(_ unitsPerHour: Double) -> Bool {
        return abs(self.unitsPerHour - unitsPerHour) < .ulpOfOne
    }

    /// Determines whether the recommendation is necessary given the current state of the pump
    ///
    /// - Parameters:
    ///   - date: The date the recommendation would be delivered
    ///   - scheduledBasalRate: The scheduled basal rate at `date`
    ///   - lastTempBasal: The previously set temp basal
    ///   - continuationInterval: The duration of time before an ongoing temp basal should be continued with a new command
    /// - Returns: A temp basal recommendation
    public func ifNecessary(
        at date: Date,
        scheduledBasalRate: Double,
        lastTempBasal: DoseEntry?,
        continuationInterval: TimeInterval
    ) -> TempBasalRecommendation? {
        // Adjust behavior for the currently active temp basal
        if let lastTempBasal = lastTempBasal,
            lastTempBasal.type == .tempBasal,
            lastTempBasal.endDate > date
        {
            /// If the last temp basal has the same rate, and has more than `continuationInterval` of time remaining, don't set a new temp
            if matchesRate(lastTempBasal.unitsPerHour),
                lastTempBasal.endDate.timeIntervalSince(date) > continuationInterval {
                return nil
            } else if matchesRate(scheduledBasalRate) {
                // If our new temp matches the scheduled rate, cancel the current temp
                return .cancel
            }
        } else if matchesRate(scheduledBasalRate) {
            // If we recommend the in-progress scheduled basal rate, do nothing
            return nil
        }

        return self
    }
}
