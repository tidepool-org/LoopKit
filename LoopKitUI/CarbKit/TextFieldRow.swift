//
//  TextFieldRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/31/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct TextFieldRow<Field: Hashable>: View {
    @Binding private var text: String
    private let focus: FocusState<Field?>.Binding
    private let field: Field
    
    let title: String
    let placeholder: String
    private let nextAction: (() -> Void)?

    public init(text: Binding<String>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, placeholder: String, next: Field? = nil) {
        self.init(text: text, focus: focus, equals: field, title: title, placeholder: placeholder, nextAction: focus.action(focusing: next))
    }

    public init(text: Binding<String>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, placeholder: String, next: @escaping () -> Void) {
        self.init(text: text, focus: focus, equals: field, title: title, placeholder: placeholder, nextAction: next)
    }

    private init(text: Binding<String>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, placeholder: String, nextAction: (() -> Void)?) {
        self._text = text
        self.focus = focus
        self.field = field
        self.title = title
        self.placeholder = placeholder
        self.nextAction = nextAction
    }

    public var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            textField
            .multilineTextAlignment(.trailing)
            .font(.body)
            .onTapGesture {
                // so that row does not lose focus on cursor move
                if focus.wrappedValue != field {
                    rowTapped()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .onTapGesture {
            rowTapped()
        }
    }

    private var textField: some View {
        KeyboardTextField(placeholder, text: $text, focus: focus, equals: field, nextAction: nextAction)
    }
    
    private func rowTapped() {
        withAnimation {
            focus.wrappedValue = focus.wrappedValue == field ? nil : field
        }
    }
}
