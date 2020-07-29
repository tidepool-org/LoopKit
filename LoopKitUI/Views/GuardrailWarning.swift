//
//  GuardrailWarning.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit


public struct GuardrailWarning: View {
    private enum CrossedThresholds {
        case one(SafetyClassification.Threshold)
        case oneOrMore([SafetyClassification.Threshold])
    }

    private var title: Text
    private var crossedThresholds: CrossedThresholds
    private var captionOverride: Text?
//    private let warningColor: Color
//    private let criticalColor: Color

    public init(
        title: Text,
        threshold: SafetyClassification.Threshold,
        caption: Text? = nil
//        warningColor: Color,
//        criticalColor: Color
    ) {
        self.title = title
        self.crossedThresholds = .one(threshold)
        self.captionOverride = caption
//        self.warningColor = warningColor
//        self.criticalColor = criticalColor
    }

    public init(
        title: Text,
        thresholds: [SafetyClassification.Threshold],
        caption: Text? = nil
//        warningColor: Color,
//        criticalColor: Color
    ) {
        precondition(!thresholds.isEmpty)
        self.title = title
        self.crossedThresholds = .oneOrMore(thresholds)
        self.captionOverride = caption
//        self.warningColor = warningColor
//        self.criticalColor = criticalColor
    }

    public var body: some View {
        WarningView(title: title, caption: caption, severity: severity)//, defaultColor: warningColor, criticalColor: criticalColor)
    }

    private var severity: WarningSeverity {
        switch crossedThresholds {
        case .one(let threshold):
            return threshold.severity
        case .oneOrMore(let thresholds):
            return thresholds.lazy.map({ $0.severity }).max()!
        }
    }

    private var caption: Text {
        if let caption = captionOverride {
            return caption
        }

        switch crossedThresholds {
        case .one(let threshold):
            switch threshold {
            case .minimum, .belowRecommended:
                return Text("The value you have chosen is lower than Tidepool generally recommends.", comment: "Warning for entering a low setting value")
            case .aboveRecommended, .maximum:
                return Text("The value you have chosen is higher than Tidepool generally recommends.", comment: "Warning for entering a high setting value")
            }
        case .oneOrMore(let thresholds):
            if thresholds.count == 1 {
                switch thresholds.first! {
                case .minimum, .belowRecommended:
                        return Text("A value you have chosen is lower than Tidepool generally recommends.", comment: "Warning for entering a low setting value in a schedule interface")
                case .aboveRecommended, .maximum:
                        return Text("A value you have chosen is higher than Tidepool generally recommends.", comment: "Warning for entering a high setting value in a schedule interface")
                }
            } else {
                return Text("Some of the values you have entered are outside of what Tidepool generally recommends.")
            }
        }
    }
}

fileprivate extension SafetyClassification.Threshold {
    var severity: WarningSeverity {
        switch self {
        case .belowRecommended, .aboveRecommended:
            return .default
        case .minimum, .maximum:
            return .critical
        }
    }
}
