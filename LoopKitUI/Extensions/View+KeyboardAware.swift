//
//  View+KeyboardAware.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

extension View {
    public func onKeyboardStateChange(perform updateForKeyboardState: @escaping (_ keyboardHeight: Keyboard.State) -> Void) -> some View {
        onReceive(Keyboard.shared.$state, perform: updateForKeyboardState)
    }

    public func keyboardEntryPage(isInteractiveDismissDisabled: Bool = false) -> some View {
        modifier(KeyboardEntryPage(isInteractiveDismissDisabled: isInteractiveDismissDisabled))
    }

    public func autoFocusOnFirstAppearance(_ shouldFocus: Binding<Bool>, enabled: @autoclosure @escaping () -> Bool = true) -> some View {
        modifier(AutoFocusOnFirstAppearance(shouldFocus: shouldFocus, enabled: enabled))
    }

    public func keyboardToolbar(isFocused: Bool, next: (() -> Void)? = nil, dismiss: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isFocused {
                    Spacer()
                    Button(
                        next == nil
                            ? LocalizedString("Done", comment: "Keyboard toolbar button that dismisses the keyboard")
                            : LocalizedString("Next", comment: "Keyboard toolbar button that moves to the next field"),
                        action: next ?? dismiss
                    )
                }
            }
        }
    }

    /// Reject oversized edits instead of truncating numeric values or device identifiers.
    public func limitTextLength(_ text: Binding<String>, to maximumLength: Int) -> some View {
        onChange(of: text.wrappedValue) { previous, current in
            if current.utf16.count > maximumLength {
                text.wrappedValue = previous
            }
        }
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
    let isInteractiveDismissDisabled: Bool
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .scrollBounceBehavior(.always)
            .scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(isInteractiveDismissDisabled || isKeyboardVisible)
            .background(KeyboardModalPinner(
                isKeyboardVisible: isKeyboardVisible,
                isInteractiveDismissDisabled: isInteractiveDismissDisabled
            ))
            .onKeyboardStateChange { state in
                isKeyboardVisible = state.height > 0
            }
    }
}

private struct KeyboardModalPinner: UIViewControllerRepresentable {
    let isKeyboardVisible: Bool
    let isInteractiveDismissDisabled: Bool

    func makeUIViewController(context: Context) -> PinnerController {
        PinnerController()
    }

    func updateUIViewController(_ controller: PinnerController, context: Context) {
        controller.setPinned(isInteractiveDismissDisabled || isKeyboardVisible)
    }

    static func dismantleUIViewController(_ controller: PinnerController, coordinator: ()) {
        controller.setPinned(false)
    }

    final class PinnerController: UIViewController {
        private weak var pinnedController: UIViewController?
        private var valueBeforePinning = false

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            if pendingPin { setPinned(true) }
        }

        private var pendingPin = false

        func setPinned(_ pinned: Bool) {
            if pinned {
                if let presented = pinnedController {
                    // A hosting controller's keyboard observer may have cleared this on hide.
                    presented.isModalInPresentation = true
                    return
                }
                guard let presented = presentedRoot() else {
                    pendingPin = true
                    return
                }
                pendingPin = false
                pinnedController = presented
                valueBeforePinning = presented.isModalInPresentation
                presented.isModalInPresentation = true
            } else {
                pendingPin = false
                guard let presented = pinnedController else { return }
                if presented.isModalInPresentation {
                    presented.isModalInPresentation = valueBeforePinning
                }
                pinnedController = nil
            }
        }

        private func presentedRoot() -> UIViewController? {
            var candidate: UIViewController? = self
            var presented: UIViewController?
            while let current = candidate {
                if current.presentingViewController != nil {
                    presented = current
                }
                candidate = current.parent
            }
            return presented
        }
    }
}
