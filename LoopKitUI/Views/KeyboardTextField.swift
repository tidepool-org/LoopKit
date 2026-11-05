//
//  KeyboardTextField.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// A `TextField` whose bound text receives only edits within `maxLength` UTF-16 units. Longer edits
/// are rejected rather than truncated, so a numeric value or device identifier is never cut short.
public struct LengthLimitedTextField: View {
    @Binding private var text: String
    @State private var enteredText: String

    private let placeholder: String
    private let maxLength: Int?

    public init(_ placeholder: String, text: Binding<String>, maxLength: Int?) {
        self.placeholder = placeholder
        self._text = text
        self.maxLength = maxLength
        self._enteredText = State(initialValue: text.wrappedValue)
    }

    public var body: some View {
        TextField(placeholder, text: editingText)
            .onChange(of: text) { _, value in
                enteredText = value
            }
            .onChange(of: enteredText) { _, value in
                if let maxLength, value.utf16.count > maxLength, value != text {
                    enteredText = text
                }
            }
    }

    private var editingText: Binding<String> {
        Binding(
            get: { enteredText },
            set: { value in
                enteredText = value
                if let maxLength, value.utf16.count > maxLength { return }
                text = value
            }
        )
    }
}

struct KeyboardTextField<Field: Hashable>: View {
    @Binding private var text: String

    private let focus: FocusState<Field?>.Binding
    private let field: Field
    private let placeholder: String
    private let keyboardType: UIKeyboardType
    private let maxLength: Int?
    private let nextAction: (() -> Void)?

    /// A `nil` `nextAction` makes this the last field, which shows Done.
    init(_ placeholder: String, text: Binding<String>, focus: FocusState<Field?>.Binding, equals field: Field, keyboardType: UIKeyboardType = .default, maxLength: Int? = nil, nextAction: (() -> Void)?) {
        self.placeholder = placeholder
        self._text = text
        self.focus = focus
        self.field = field
        self.keyboardType = keyboardType
        self.maxLength = maxLength
        self.nextAction = nextAction
    }

    var body: some View {
        input
            .textFieldStyle(.plain)
            .keyboardType(keyboardType)
    }

    @ViewBuilder
    private var input: some View {
        let textField = LengthLimitedTextField(placeholder, text: $text, maxLength: maxLength)
        if let nextAction {
            textField.inputField(focus: focus, equals: field, next: nextAction)
        } else {
            textField.inputField(focus: focus, equals: field)
        }
    }
}

extension FocusState.Binding {
    /// An action that focuses `next`, or `nil` when there is no next field.
    func action<Field: Hashable>(focusing next: Field?) -> (() -> Void)? where Value == Field? {
        next.map { next in { self.wrappedValue = next } }
    }
}
