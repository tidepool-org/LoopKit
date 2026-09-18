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

public extension View {
    func actionAreaShadow() -> some View {
        background(
            Color(.secondarySystemGroupedBackground)
                .shadow(radius: 5)
                .ignoresSafeArea([.container, .keyboard], edges: .bottom)
        )
    }

    func actionAreaInset<BarContent: View>(@ViewBuilder _ barContent: () -> BarContent) -> some View {
        modifier(SeatedActionAreaInset(barContent: barContent()))
    }
}

private struct SeatedActionAreaInset<BarContent: View>: ViewModifier {
    let barContent: BarContent

    @State private var isKeyboardVisible = false
    @State private var actionAreaHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: isKeyboardVisible ? 0 : actionAreaHeight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay {
                ActionArea { barContent }
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.height
                    } action: { height in
                        actionAreaHeight = height
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .onKeyboardStateChange { state in
                isKeyboardVisible = state.height > 0
            }
    }
}
