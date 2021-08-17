//
//  GlucoseTherapySettingInformationView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 11/16/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public struct GlucoseTherapySettingInformationView: View {
    var text: AnyView?
    let onExit: (() -> Void)?
    let mode: SettingsPresentationMode
    let therapySetting: TherapySetting
    let appName: String
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable

    private var displayGlucoseUnit: HKUnit {
        displayGlucoseUnitObservable.displayGlucoseUnit
    }

    public init(
        therapySetting: TherapySetting,
        onExit: (() -> Void)?,
        mode: SettingsPresentationMode = .acceptanceFlow,
        appName: String,
        text: AnyView? = nil
    ){
        self.therapySetting = therapySetting
        self.onExit = onExit
        self.mode = mode
        self.appName = appName
        self.text = text
    }
    
    public var body: some View {
        InformationView(
            title: Text(self.therapySetting.title),
            informationalContent: {
                illustration
                bodyText
            },
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var illustration: some View {
        Image(frameworkImage: illustrationImageName)
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: ContentMode.fit)
    }
    
    private var bodyText: some View {
        VStack(alignment: .leading, spacing: 25) {
            text ?? AnyView(Text(therapySetting.descriptiveText(appName: appName)))
            Text(therapySetting.guardrailInformationText(displayGlucoseUnit: displayGlucoseUnit))
        }
        .accentColor(.secondary)
        .foregroundColor(.accentColor)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var illustrationImageName: String {
        return "\(therapySetting) \(displayGlucoseUnit.description.replacingOccurrences(of: "/", with: ""))"
    }
}

fileprivate extension TherapySetting {
    func guardrailInformationText(displayGlucoseUnit: HKUnit) -> String {
        switch self {
        case .glucoseTargetRange:
            return lowHighText(for: Guardrail.correctionRange, displayGlucoseUnit: displayGlucoseUnit)
        case .preMealCorrectionRangeOverride:
            return lowHighText(lowerBoundString: LocalizedString("your Glucose Safety Limit", comment: "Lower bound pre-meal information text"),
                               upperBoundString: Guardrail.premealCorrectionRangeMaximum.stringForGlucoseUnit(displayGlucoseUnit))
        case .workoutCorrectionRangeOverride:
            return lowHighText(
                lowerBoundString: String(format: LocalizedString("%1$@ or your Glucose Safety Limit, whichever is higher", comment: "Lower bound workout information text format (1: app name)"), Guardrail.unconstrainedWorkoutCorrectionRange.absoluteBounds.lowerBound.stringForGlucoseUnit(displayGlucoseUnit)),
                upperBoundString: Guardrail.unconstrainedWorkoutCorrectionRange.absoluteBounds.upperBound.stringForGlucoseUnit(displayGlucoseUnit))
        case .suspendThreshold:
            return lowHighText(for: Guardrail.suspendThreshold, displayGlucoseUnit: displayGlucoseUnit)
        case .basalRate, .deliveryLimits, .insulinModel, .carbRatio, .insulinSensitivity, .none:
            fatalError("Unexpected")
        }
    }
       
    func lowHighText(for guardrail: Guardrail<HKQuantity>, displayGlucoseUnit: HKUnit) -> String {
        return lowHighText(lowerBoundString: guardrail.absoluteBounds.lowerBound.stringForGlucoseUnit(displayGlucoseUnit),
                           upperBoundString: guardrail.absoluteBounds.upperBound.stringForGlucoseUnit(displayGlucoseUnit))
    }

    func lowHighText(lowerBoundString: String, upperBoundString: String) -> String {
        return String(format: LocalizedString("It can be set as low as %1$@. It can be set as high as %2$@.",
                                              comment: "Guardrail info text format"), lowerBoundString, upperBoundString)
    }
}
