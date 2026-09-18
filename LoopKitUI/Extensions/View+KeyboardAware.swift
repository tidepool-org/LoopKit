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

    /// Install on the page containing the fields so scrolling content avoids the entire action bar.
    /// Apply before `actionAreaInset` so the page's footer stays behind the keyboard.
    public func keyboardToolbar(isFocused: Bool, next: (() -> Void)? = nil, dismiss: @escaping () -> Void) -> some View {
        modifier(KeyboardToolbar(isFocused: isFocused, next: next, dismiss: dismiss))
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

private struct KeyboardToolbar: ViewModifier {
    let isFocused: Bool
    let next: (() -> Void)?
    let dismiss: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .bottom, spacing: 0) {
                actions
            }
        } else {
            content
                .scrollBounceBehavior(.always)
                .scrollDismissesKeyboard(.interactively)
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

    @available(iOS 26.0, *)
    @ViewBuilder
    private var actions: some View {
        if isFocused {
            HStack {
                Spacer()
                button
                    .buttonStyle(KeyboardToolbarButtonStyle())
            }
            .padding(.horizontal, KeyboardDismissAccessory.horizontalSpacing)
            .padding(.vertical, KeyboardDismissAccessory.verticalSpacing)
        }
    }

    private var button: some View {
        Button(
            next == nil
                ? LocalizedString("Done", comment: "Keyboard toolbar button that dismisses the keyboard")
                : LocalizedString("Next", comment: "Keyboard toolbar button that moves to the next field"),
            action: next ?? dismiss
        )
    }
}

@available(iOS 26.0, *)
private struct KeyboardToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        paddedLabel(configuration.label)
            .glassEffect(.regular.interactive(), in: .capsule)
            .frame(minWidth: KeyboardDismissAccessory.minimumHitTarget,
                   minHeight: KeyboardDismissAccessory.minimumHitTarget,
                   alignment: .bottom)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }

    private func paddedLabel(_ label: Configuration.Label) -> some View {
        label
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.horizontal, KeyboardDismissAccessory.horizontalContentInset)
            .padding(.vertical, KeyboardDismissAccessory.verticalContentInset)
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
