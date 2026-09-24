//
//  KeyboardTextField.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct KeyboardTextField<Field: Hashable>: View {
    @Binding private var text: String
    @State private var enteredText: String

    private let focus: FocusState<Field?>.Binding
    private let field: Field
    private let placeholder: String
    private let keyboardType: UIKeyboardType
    private let maxLength: Int?
    private let nextField: Field?
    private var nextAction: (() -> Void)?

    public init(_ placeholder: String, text: Binding<String>, focus: FocusState<Field?>.Binding, equals field: Field, keyboardType: UIKeyboardType = .default, maxLength: Int? = nil, next: Field? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.focus = focus
        self.field = field
        self.keyboardType = keyboardType
        self.maxLength = maxLength
        self.nextField = next
        self._enteredText = State(initialValue: text.wrappedValue)
    }

    public init(_ placeholder: String, text: Binding<String>, focus: FocusState<Field?>.Binding, equals field: Field, keyboardType: UIKeyboardType = .default, maxLength: Int? = nil, next: @escaping () -> Void) {
        self.init(placeholder, text: text, focus: focus, equals: field, keyboardType: keyboardType, maxLength: maxLength)
        self.nextAction = next
    }

    public var body: some View {
        input
            .textFieldStyle(.plain)
            .keyboardType(keyboardType)
            .onChange(of: text) { _, value in
                enteredText = value
            }
            .onChange(of: enteredText) { _, value in
                if let maxLength, value.utf16.count > maxLength, value != text {
                    enteredText = text
                }
            }
    }

    @ViewBuilder
    private var input: some View {
        if let nextAction {
            TextField(placeholder, text: editingText)
                .inputField(focus: focus, equals: field, next: nextAction)
        } else {
            TextField(placeholder, text: editingText)
                .inputField(focus: focus, equals: field, next: nextField)
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
