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

    /// Requests initial focus without replacing a field the user has already focused.
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

    /// Connects a native field to focus and a Done return key without changing its style or data.
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
    }

    /// Declares native focus and the Next/Done action for both Return and the form toolbar.
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
