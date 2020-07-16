//
//  InsulinModelInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct InsulinModelInformationView: View {
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
            title: Text(LocalizedString("Insulin Model", comment: "Title for insulin model informational screen")),
            buttonText: Text(LocalizedString("Next: Review Setting", comment: "Button to advance to setting selector")),
            informationalContent: {
                VStack (alignment: .leading, spacing: 20) {
                    diaInfo
                    modelPeakInfo
                }
                .foregroundColor(blueGray)
            },
            onExit: exitPage,
            mode: mode)
    }
    
    private var diaInfo: Text {
        Text(LocalizedString("Tidepool Loop assumes that the insulin it has delivered is actively working to lower your glucose for 6 hours. This setting cannot be changed.", comment: "Information about insulin action duration"))
    }
    
    private var modelPeakInfo: some View {
        VStack (alignment: .leading, spacing: 20) {
            Text(LocalizedString("You can choose how Tidepool Loop measures the insulin's peak activity according to one of these two insulin models.", comment: "Information about insulin model"))
            HStack(spacing: 10) {
                bulletCircle
                Text(LocalizedString("The rapid-acting adult model assumes peak activity at 75 minutes.", comment: "Information about adult insulin model"))
            }
            HStack(spacing: 10) {
                bulletCircle
                Text(LocalizedString("The rapid-acting child model assumes peak activity at 65 minutes.", comment: "Information about child insulin model"))
            }
        }
    }
    
    private var bulletCircle: some View {
        Image(systemName: "circle.fill")
        .resizable()
        .frame(width: 10, height: 10)
    }
}
