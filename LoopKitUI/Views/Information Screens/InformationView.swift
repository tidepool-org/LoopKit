//
//  InformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public enum PresentationMode {
    case modal, flow
}

struct InformationView<InformationalContent: View> : View {
    var informationalContent: InformationalContent
    var title: Text
    var buttonText: Text
    var exitPage: (() -> Void)
    let mode: PresentationMode
    
    init(
        title: Text,
        buttonText: Text,
        @ViewBuilder informationalContent: () -> InformationalContent,
        exitPage: @escaping () -> Void,
        mode: PresentationMode = .flow
    ) {
        self.title = title
        self.buttonText = buttonText
        self.informationalContent = informationalContent()
        self.exitPage = exitPage
        self.mode = mode
    }
    
    var body: some View {
        bodyWithCancelButtonIfNeeded
        .navigationBarTitle(title)
    }
    
    var bodyWithCancelButtonIfNeeded: some View {
        // ANNA TODO: remove anyviews if possible
        switch mode {
        case .flow:
            return AnyView(bodyWithBottomButton)
        case .modal:
            return AnyView(bodyWithCancelButton)
        }
    }
    
    var bodyWithBottomButton: some View {
        VStack (alignment: .leading, spacing: 20) {
            informationalContent
            Spacer()
            nextPageButton
        }
        .padding()
    }
    
    var bodyWithCancelButton: some View {
        VStack (alignment: .leading, spacing: 20) {
            informationalContent
            Spacer()
        }
        .padding()
        .navigationBarItems(leading: cancelButton)
    }
    
    var cancelButton: some View {
        Button(action: exitPage, label: { Text("Cancel") })
    }
    
    var nextPageButton: some View {
        Button(action: exitPage) {
            buttonText
            .actionButtonStyle(.primary)
        }
    }
}
