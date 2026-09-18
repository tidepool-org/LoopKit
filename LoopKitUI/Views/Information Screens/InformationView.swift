//
//  InformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct InformationView<InformationalContent: View> : View {
    var informationalContent: InformationalContent
    var title: Text
    var buttonText: Text
    var onExit: (() -> Void)
    let mode: SettingsPresentationMode

    @State private var scrollViewHeight: CGFloat = 0
    
    init(
        title: Text,
        buttonText: Text,
        @ViewBuilder informationalContent: () -> InformationalContent,
        onExit: @escaping () -> Void,
        mode: SettingsPresentationMode
    ) {
        self.title = title
        self.buttonText = buttonText
        self.informationalContent = informationalContent()
        self.onExit = onExit
        self.mode = mode
    }
    
    // Convenience initializer for info view w/next page button
    init(
        title: Text,
        @ViewBuilder informationalContent: () -> InformationalContent,
        onExit: @escaping () -> Void,
        mode: SettingsPresentationMode = .acceptanceFlow
    ) {
        self.init(
            title: title,
            buttonText: Text(LocalizedString("Continue", comment: "Button to advance to setting editor")),
            informationalContent: informationalContent,
            onExit: onExit,
            mode: mode
        )
    }
    
    var body: some View {
        switch mode {
        case .acceptanceFlow:
            ScrollView {
                bodyForAcceptanceFlow
                    .padding()
            }
            .actionAreaInset {
                nextPageButton
            }
        case .settings:
            ScrollView {
                bodyForSettings
                    .padding()
                    .frame(minHeight: scrollViewHeight)
            }
            .background(
                GeometryReader { geometry in
                    let visibleHeight = geometry.size.height - (geometry.frame(in: .global).maxY > UIScreen.main.bounds.height - geometry.safeAreaInsets.bottom + 0.5 ? geometry.safeAreaInsets.bottom : 0)
                    Color.clear
                        .onAppear { scrollViewHeight = visibleHeight }
                        .onChange(of: visibleHeight) { _, height in
                            scrollViewHeight = height
                        }
                }
            )
        }
    }
    
    private var bodyForAcceptanceFlow: some View {
        VStack(alignment: .leading, spacing: 20) {
            titleView
            Divider()
            informationalContent
        }
    }
    
    private var bodyForSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            informationalContent
            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                cancelButton
            }
        }
        .navigationBarTitle(title, displayMode: .large)
    }

    private var titleView: some View {
        title
            .font(.largeTitle)
            .bold()
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("titleText_therapySettingsEducationTitle")
    }
    
    private var cancelButton: some View {
        Button(action: onExit, label: { Text(LocalizedString("Close", comment: "Text to close informational page")) })
            .accessibilityIdentifier("button_close")
    }
    
    private var nextPageButton: some View {
        Button(action: onExit) {
            buttonText
        }
        .buttonStyle(ActionButtonStyle(.primary))
        .accessibilityIdentifier("button_continue")
    }
}
