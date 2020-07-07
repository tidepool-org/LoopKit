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
    var onExit: (() -> Void)
    let mode: PresentationMode
    
    init(
        title: Text,
        buttonText: Text,
        @ViewBuilder informationalContent: () -> InformationalContent,
        onExit: @escaping () -> Void,
        mode: PresentationMode = .flow
    ) {
        self.title = title
        self.buttonText = buttonText
        self.informationalContent = informationalContent()
        self.onExit = onExit
        self.mode = mode
    }
    
    var body: some View {
        ScrollView {
            bodyWithCancelButtonIfNeeded
            .navigationBarTitle(Text(""), displayMode: .inline)
            .padding()
        }
    }
    
    private var inBodyTitle: Text {
        title
        .bold()
        .font(.largeTitle)
    }
    
    private var bodyWithCancelButtonIfNeeded: some View {
        switch mode {
        case .flow:
            return AnyView(bodyWithBottomButton)
        case .modal:
            return AnyView(bodyWithCancelButton)
        }
    }
    
    private var bodyWithBottomButton: some View {
        VStack(alignment: .leading, spacing: 20) {
            inBodyTitle
            informationalContent
            Spacer()
            nextPageButton
        }
    }
    
    private var bodyWithCancelButton: some View {
        VStack(alignment: .leading, spacing: 20) {
            inBodyTitle
            informationalContent
            Spacer()
        }
        .navigationBarItems(leading: cancelButton)
    }
    
    private var cancelButton: some View {
        Button(action: onExit, label: { Text("Cancel") })
    }
    
    private var nextPageButton: some View {
        Button(action: onExit) {
            buttonText
            .actionButtonStyle(.primary)
        }
    }
}
