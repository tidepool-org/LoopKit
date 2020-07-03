//
//  DeliveryLimitsInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct DeliveryLimitsInformationView: View {
    let blueGray = Color("Blue Gray", bundle: Bundle(for: DismissibleHostingController.self))
    var exitPage: (() -> Void)
    var mode: PresentationMode
    
    public init(exitPage: @escaping (() -> Void),
                mode: PresentationMode = .flow) {
        self.exitPage = exitPage
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(LocalizedString("Delivery Limits", comment: "Title for delivery limit info page")),
            buttonText: Text(LocalizedString("Next: Review Setting", comment: "Button to advance to setting editor")),
            informationalContent: {
                VStack (alignment: .leading, spacing: 20) {
                    deliveryLimitDescription
                    maxBasalDescription
                    maxBolusDescription
                }
                .fixedSize(horizontal: false, vertical: true) // prevent text from being cut off
            },
            exitPage: exitPage,
            mode: mode)
    }
    
    private var deliveryLimitDescription: some View {
        Text(LocalizedString("Delivery limits are safety guardrails for your insulin delivery.", comment: "Information about delivery limits"))
        .foregroundColor(blueGray)
    }
    
    private var maxBasalDescription: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LocalizedString("Maximum basal rate", comment: "Maximum basal rate title"))
            .font(.headline)
            VStack {
                Text(LocalizedString("Maximum basal rate is the maximum automatically adjusted basal rate that Tidepool Loop is allowed to enact to help reach your correction range.", comment: "Information about maximum basal rate"))
                Text(LocalizedString("Some users choose a value 2, 3, or 4 times their highest scheduled basal rate.", comment: "Information about typical maximum basal rates"))
                Text(LocalizedString("Work with your healthcare provider to choose a value that is higher than your highest scheduled basal rate, but as conservative or aggressive as you feel comfortable.", comment: "Disclaimer"))
            }
            .foregroundColor(blueGray)
        }
    }
    
    private var maxBolusDescription: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LocalizedString("Maximum bolus", comment: "Maximum bolus title"))
            .font(.headline)
            Text(LocalizedString("Maximum bolus is the highest bolus amount that you will allow Tidepool Loop to recommend at one time to cover carbs or bring down high glucose.", comment: "Information about maximum bolus"))
            .foregroundColor(blueGray)
        }
    }
}

