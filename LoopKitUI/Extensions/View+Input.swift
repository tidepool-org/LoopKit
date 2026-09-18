//
//  View+Input.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

public extension View {
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
