//
//  View+Input.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit

public extension View {
    /// Requests native focus once, after the page's first appearance transition finishes.
    /// Apply to the page so returning from another screen does not reopen the keyboard.
    func initialFocus(
        _ focus: FocusState<Bool>.Binding,
        when enabled: Bool = true
    ) -> some View {
        modifier(InitialInputFocus(focus: focus, target: true, unfocused: false, enabled: enabled))
    }

    func initialFocus<Field: Hashable>(
        _ focus: FocusState<Field?>.Binding,
        equals field: Field,
        when enabled: Bool = true
    ) -> some View {
        modifier(InitialInputFocus(focus: focus, target: field, unfocused: nil, enabled: enabled))
    }

    /// Configures one keyboard entry page, including its toolbar, swipe dismissal,
    /// modal protection, and focus cleanup. Apply before `actionAreaInset`.
    func inputForm(
        focus: FocusState<Bool>.Binding,
        isInteractiveDismissDisabled: Bool = false
    ) -> some View {
        modifier(BooleanInputFormNavigation(
            focus: focus,
            isInteractiveDismissDisabled: isInteractiveDismissDisabled
        ))
    }

    /// Uses native focus state and the active `inputField`'s Next/Done declaration.
    func inputForm<Field: Hashable>(
        focus: FocusState<Field?>.Binding,
        isInteractiveDismissDisabled: Bool = false
    ) -> some View {
        modifier(InputFormNavigation(
            focus: focus,
            isInteractiveDismissDisabled: isInteractiveDismissDisabled
        ))
    }

    /// Escape hatch for pages that combine multiple independently focused fields.
    func inputForm(
        isFocused: Bool,
        next: (() -> Void)? = nil,
        isInteractiveDismissDisabled: Bool = false,
        dismiss: @escaping () -> Void
    ) -> some View {
        inputForm(isInteractiveDismissDisabled: isInteractiveDismissDisabled)
            .keyboardToolbar(isFocused: isFocused, next: next, dismiss: dismiss)
            .onDisappear(perform: dismiss)
    }

    /// Connects a native field to focus, with a Done or Next return key and toolbar action.
    /// Tapping the unfocused field puts the caret after its text, wherever the tap lands.
    func inputField(focus: FocusState<Bool>.Binding, next: (() -> Void)? = nil) -> some View {
        focused(focus)
            .submitLabel(next == nil ? .done : .next)
            .onSubmit {
                if let next {
                    next()
                } else {
                    focus.wrappedValue = false
                }
            }
            .focusedValue(
                \.inputFieldNavigation,
                InputFieldNavigation(field: AnyHashable(true), nextAction: next)
            )
            .modifier(FocusOnTapWithCaretAtEnd(isFocused: focus.wrappedValue) {
                focus.wrappedValue = true
            })
    }

    /// Declares native focus and the Next/Done action for both Return and the form toolbar.
    /// Tapping the unfocused field puts the caret after its text, wherever the tap lands.
    func inputField<Field: Hashable>(
        focus: FocusState<Field?>.Binding,
        equals field: Field,
        next: Field? = nil
    ) -> some View {
        focused(focus, equals: field)
            .submitLabel(next == nil ? .done : .next)
            .onSubmit { focus.wrappedValue = next }
            .focusedValue(
                \.inputFieldNavigation,
                InputFieldNavigation(field: AnyHashable(field), next: next.map(AnyHashable.init))
            )
            .modifier(FocusOnTapWithCaretAtEnd(isFocused: focus.wrappedValue == field) {
                focus.wrappedValue = field
            })
    }

    /// Uses one callback for Return and toolbar Next when advancing to a custom input.
    func inputField<Field: Hashable>(
        focus: FocusState<Field?>.Binding,
        equals field: Field,
        next: @escaping () -> Void
    ) -> some View {
        focused(focus, equals: field)
            .submitLabel(.next)
            .onSubmit(next)
            .focusedValue(
                \.inputFieldNavigation,
                InputFieldNavigation(field: AnyHashable(field), nextAction: next)
            )
            .modifier(FocusOnTapWithCaretAtEnd(isFocused: focus.wrappedValue == field) {
                focus.wrappedValue = field
            })
    }

}

/// A native field puts the caret where a tap lands, which in a right-aligned value is usually before the
/// digits (LOOP-1916). Taps on an unfocused field focus it in code instead, which leaves the caret after
/// the text; once the field is focused, taps reach it and move the caret as usual.
private struct FocusOnTapWithCaretAtEnd: ViewModifier {
    let isFocused: Bool
    let focus: () -> Void

    func body(content: Content) -> some View {
        content
            // Moving the caret in the focused field doesn't also trigger an enclosing row's tap gesture.
            .onTapGesture {}
            .overlay {
                if !isFocused {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: focus)
                        .accessibilityHidden(true)
                }
            }
    }
}

private struct InitialInputFocus<Value: Hashable>: ViewModifier {
    let focus: FocusState<Value>.Binding
    let target: Value
    let unfocused: Value
    let enabled: Bool
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content.background {
            InputAppearanceObserver {
                guard !hasAppeared else { return }
                hasAppeared = true
                guard enabled, focus.wrappedValue == unfocused else { return }
                focus.wrappedValue = target
            }
        }
    }
}

/// SwiftUI's onAppear runs before a navigation transition completes. Wait for UIKit's
/// completed appearance so a coordinator's endEditing call cannot cancel initial focus.
private struct InputAppearanceObserver: UIViewControllerRepresentable {
    let onAppear: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.onAppear = onAppear
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onAppear = onAppear
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.onAppear = nil
    }

    final class Controller: UIViewController {
        var onAppear: (() -> Void)?

        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onAppear?()
        }
    }
}

private struct InputFieldNavigation {
    let field: AnyHashable
    var next: AnyHashable? = nil
    var nextAction: (() -> Void)? = nil
}

private extension FocusedValues {
    @Entry var inputFieldNavigation: InputFieldNavigation?
}

private struct BooleanInputFormNavigation: ViewModifier {
    let focus: FocusState<Bool>.Binding
    let isInteractiveDismissDisabled: Bool
    @FocusedValue(\.inputFieldNavigation) private var navigation

    func body(content: Content) -> some View {
        content.inputForm(
            isFocused: focus.wrappedValue,
            next: navigation?.field == AnyHashable(true) ? navigation?.nextAction : nil,
            isInteractiveDismissDisabled: isInteractiveDismissDisabled,
            dismiss: { focus.wrappedValue = false }
        )
    }
}

private struct InputFormNavigation<Field: Hashable>: ViewModifier {
    let focus: FocusState<Field?>.Binding
    let isInteractiveDismissDisabled: Bool
    @FocusedValue(\.inputFieldNavigation) private var navigation

    func body(content: Content) -> some View {
        content.inputForm(
            isFocused: focus.wrappedValue != nil,
            next: nextAction,
            isInteractiveDismissDisabled: isInteractiveDismissDisabled,
            dismiss: { focus.wrappedValue = nil }
        )
    }

    private var nextAction: (() -> Void)? {
        guard let field = focus.wrappedValue,
              let navigation,
              navigation.field == AnyHashable(field) else {
            return nil
        }
        if let nextAction = navigation.nextAction {
            return nextAction
        }
        guard let next = navigation.next?.base as? Field else { return nil }
        return { focus.wrappedValue = next }
    }
}
