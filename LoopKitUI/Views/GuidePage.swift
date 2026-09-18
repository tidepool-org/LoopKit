//
//  GuidePage.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2020-03-04.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct GuidePage<Content, ActionAreaContent>: View where Content: View, ActionAreaContent: View {
    let content: Content
    let actionAreaContent: ActionAreaContent

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    public init(@ViewBuilder content: @escaping () -> Content,
         @ViewBuilder actionAreaContent: @escaping () -> ActionAreaContent)
    {
        self.content = content()
        self.actionAreaContent = actionAreaContent()
    }

    public init(@ViewBuilder content: @escaping () -> Content) where ActionAreaContent == EmptyView {
        self.content = content()
        self.actionAreaContent = EmptyView()
    }

    @ViewBuilder
    public var body: some View {
        if ActionAreaContent.self == EmptyView.self {
            listContent
        } else {
            listContent
                .actionAreaInset {
                    self.actionAreaContent
                }
        }
    }

    private var listContent: some View {
        List {
            if self.horizontalSizeClass == .compact {
                Section(header: EmptyView(), footer: EmptyView()) {
                    self.content
                }
            } else {
                self.content
            }
        }
        .insetGroupedListStyle()
    }
}

struct GuidePage_Previews: PreviewProvider {
    static var previews: some View {
        GuidePage(content: {
            Text("content")
            Text("more content")
            Image(systemName: "circle")
        }) {
            Button(action: {
                print("Button tapped")
            }) {
                Text("Action Button")
            }
            .buttonStyle(ActionButtonStyle())
        }
    }
}
