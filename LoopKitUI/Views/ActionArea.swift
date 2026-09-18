//
//  ActionArea.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct ActionArea<Content: View>: View {
    private let content: Content

    @State private var bottomSafeAreaInset: CGFloat = 0

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if Content.self != EmptyView.self {
            VStack(spacing: 12) {
                content
            }
            .padding([.horizontal, .top])
            .padding(.bottom, bottomSafeAreaInset > 0 ? 12 : 16)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { bottomSafeAreaInset = geometry.safeAreaInsets.bottom }
                        .onChange(of: geometry.safeAreaInsets.bottom) { _, inset in
                            bottomSafeAreaInset = inset
                        }
                }
            )
            .actionAreaShadow()
        }
    }
}

public struct SecondaryActionButton: View {
    private let title: Text
    private let action: () -> Void

    public init(_ title: Text, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        HStack {
            Spacer()
            Button(action: action) { title.bold() }
                .padding(8)
            Spacer()
        }
    }
}

public extension View {
    func actionAreaShadow() -> some View {
        background(
            Color(.secondarySystemGroupedBackground)
                .shadow(radius: 5)
                .ignoresSafeArea([.container, .keyboard], edges: .bottom)
        )
    }

    @ViewBuilder
    func actionAreaInset<BarContent: View>(@ViewBuilder _ barContent: () -> BarContent) -> some View {
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .bottom, spacing: 0) { ActionArea(content: barContent) }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) { ActionArea(content: barContent) }
        }
    }
}
