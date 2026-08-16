//
//  View+KeyboardAware.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


// NOTE: In iOS 14, keyboard management is handled automatically in SwiftUI.
extension View {
    public func onKeyboardStateChange(perform updateForKeyboardState: @escaping (_ keyboardHeight: Keyboard.State) -> Void) -> some View {
        onReceive(Keyboard.shared.$state, perform: updateForKeyboardState)
    }

    public func keyboardEntryPage() -> some View {
        modifier(KeyboardEntryPage())
    }

    public func autoFocusOnFirstAppearance(_ shouldFocus: Binding<Bool>, enabled: @autoclosure @escaping () -> Bool = true) -> some View {
        modifier(AutoFocusOnFirstAppearance(shouldFocus: shouldFocus, enabled: enabled))
    }
}

private struct AutoFocusOnFirstAppearance: ViewModifier {
    @Binding var shouldFocus: Bool
    let enabled: () -> Bool

    @State private var hasAutoFocused = false
    @State private var isVisible = false

    private static var transitionSettleDelay: TimeInterval { 0.5 }

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                guard !hasAutoFocused, enabled() else { return }
                hasAutoFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.transitionSettleDelay) {
                    guard isVisible else { return }
                    shouldFocus = true
                }
            }
            .onDisappear {
                isVisible = false
                shouldFocus = false
            }
    }
}

private struct KeyboardEntryPage: ViewModifier {
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .scrollBounceBehavior(.always)
            .scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(isKeyboardVisible)
            .onKeyboardStateChange { state in
                isKeyboardVisible = state.height > 0
            }
    }
}

@available(iOSApplicationExtension, unavailable)
public enum KeyboardDismissal {
    public static func resignFirstResponder() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
