//
//  View+KeyboardFieldVisibility.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

public extension View {
    /// Keeps the active row above the keyboard and its action bar as the viewport shrinks.
    /// Install on the scroll container inside a `ScrollViewReader`, and give each target row an ID.
    func keepKeyboardFieldVisible<Field: Hashable>(
        _ field: Field?,
        in scrollProxy: ScrollViewProxy,
        anchor: UnitPoint = .center
    ) -> some View {
        modifier(KeyboardFieldVisibility(field: field, scrollProxy: scrollProxy, anchor: anchor))
    }
}

private struct KeyboardFieldVisibility<Field: Hashable>: ViewModifier {
    let field: Field?
    let scrollProxy: ScrollViewProxy
    let anchor: UnitPoint
    @State private var viewportHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onChange(of: field) { _, _ in
                scrollToField()
            }
            .onGeometryChange(for: CGFloat.self) { geometry in
                max(0, geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom)
            } action: { height in
                viewportHeight = height
            }
            .onChange(of: viewportHeight) { previousHeight, height in
                if height < previousHeight {
                    scrollToField()
                }
            }
    }

    private func scrollToField() {
        guard let field else { return }
        scrollProxy.scrollTo(field, anchor: anchor)
    }
}
