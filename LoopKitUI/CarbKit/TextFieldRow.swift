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
    private let nextField: Field?
    private var nextAction: (() -> Void)?
    
    public init(text: Binding<String>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, placeholder: String, next: Field? = nil) {
        self._text = text
        self.focus = focus
        self.field = field
        self.title = title
        self.placeholder = placeholder
        self.nextField = next
    }

    public init(text: Binding<String>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, placeholder: String, next: @escaping () -> Void) {
        self.init(text: text, focus: focus, equals: field, title: title, placeholder: placeholder)
        self.nextAction = next
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

    @ViewBuilder
    private var textField: some View {
        if let nextAction {
            KeyboardTextField(placeholder, text: $text, focus: focus, equals: field, next: nextAction)
        } else {
            KeyboardTextField(placeholder, text: $text, focus: focus, equals: field, next: nextField)
        }
    }
    
    private func rowTapped() {
        withAnimation {
            focus.wrappedValue = focus.wrappedValue == field ? nil : field
        }
    }
}
