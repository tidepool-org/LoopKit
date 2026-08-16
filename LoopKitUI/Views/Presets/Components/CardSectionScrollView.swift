//
//  CardSectionScrollView.swift
//  Loop
//
//  Created by Pete Schwamb on 3/7/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

// Container designed to hold CardSection views in a scrollview, and an optional action area
// that the scrollview would flow under, with a shadow effect. Together, they replace a List (TableView)
// with grouped styling, and allow rows to have their height animated as expected, avoiding the animation
// issues that resizing rows in Lists presents.

import SwiftUI

public struct CardSectionScrollView<Content: View, ActionAreaContent: View>: View {
    let content: Content
    let actionArea: ActionAreaContent?

    // Initializer for custom view header
    public init(@ViewBuilder content: () -> Content, @ViewBuilder actionArea: () -> ActionAreaContent) {
        self.content = content()
        self.actionArea = actionArea()
    }

    // Initializer for no action area
    public init(@ViewBuilder content: () -> Content) where ActionAreaContent == Text {
        self.content = content()
        self.actionArea = nil
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading) {
                    content
                }
                .padding()
            }
            if let actionArea {
                FloatingActionArea {
                    actionArea
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}
