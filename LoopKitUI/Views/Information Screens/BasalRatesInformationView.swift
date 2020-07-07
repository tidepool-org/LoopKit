//
//  BasalRatesInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct BasalRatesInformationView: View {
    let blueGray = Color("Blue Gray", bundle: Bundle(for: DismissibleHostingController.self))
    var onExit: (() -> Void)?
    var mode: PresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(onExit: (() -> Void)?,
                mode: PresentationMode = .flow) {
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(LocalizedString("Basal Rates", comment: "Title for basal rate informational screen")),
            buttonText: Text(LocalizedString("Next: Review Setting", comment: "Button to advance to setting editor")),
            informationalContent: {text},
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode)
    }
    
    private var text: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(LocalizedString("Your basal rate of insulin is the number of units per hour that you want to use to cover your background insulin needs.", comment: "Information about basal rates"))
            Text(LocalizedString("Tidepool Loop supports 1 to 48 rates per day.", comment: "Information about max number of basal rates"))
            Text(LocalizedString("The schedule starts at midnight and cannot contain a rate of 0 U/hr.", comment: "Information about basal rate scheduling"))
        }
        .foregroundColor(blueGray)
    }
}
