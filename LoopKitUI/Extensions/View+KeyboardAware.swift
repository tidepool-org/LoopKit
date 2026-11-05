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

    public func inputForm(isInteractiveDismissDisabled: Bool = false) -> some View {
        modifier(InputForm(isInteractiveDismissDisabled: isInteractiveDismissDisabled))
    }

    /// Install on the page containing the fields so scrolling content avoids the entire action bar.
    /// Apply before `actionAreaInset` so the page's footer stays behind the keyboard.
    public func keyboardToolbar(isFocused: Bool, next: (() -> Void)? = nil, dismiss: @escaping () -> Void) -> some View {
        modifier(KeyboardToolbar(isFocused: isFocused, next: next, dismiss: dismiss))
    }
}

private struct KeyboardToolbar: ViewModifier {
    let isFocused: Bool
    let next: (() -> Void)?
    let dismiss: () -> Void

    func body(content: Content) -> some View {
        let content = content
            .scrollBounceBehavior(.always)
            .scrollDismissesKeyboard(.interactively)
        if #available(iOS 26.0, *) {
            content
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    if isFocused {
                        HStack {
                            Spacer()
                            button
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .buttonStyle(.glass)
                                .controlSize(.regular)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
        } else {
            content
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if isFocused {
                            Spacer()
                            button
                                .fontWeight(.semibold)
                        }
                    }
                }
        }
    }

    private var button: some View {
        let button = KeyboardToolbarButton(hasNext: next != nil)
        return Button(button.title, action: next ?? dismiss)
            .accessibilityIdentifier(button.accessibilityIdentifier)
    }
}

private struct InputForm: ViewModifier {
    let isInteractiveDismissDisabled: Bool
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
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
