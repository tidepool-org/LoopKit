//
//  RowTextField.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// A text field that supports custom input keyboards, moves the cursor to the end of the text, becomes the first responder when it's the focused row, and loses first responder when it's not
struct RowTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var maxLength: Int? = nil
    var next: (() -> Void)? = nil
    var configuration = { (view: CustomInputTextField) in }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, isFocused: $isFocused, maxLength: maxLength, next: next)
    }

    func makeUIView(context: UIViewRepresentableContext<RowTextField>) -> CustomInputTextField {
        let textField = CustomInputTextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: CustomInputTextField, context: UIViewRepresentableContext<RowTextField>) {
        if textField.text != text {
            textField.text = text
        }
        configuration(textField)
        let returnKeyType: UIReturnKeyType = next == nil ? .done : .next
        if textField.returnKeyType != returnKeyType {
            textField.returnKeyType = returnKeyType
        }
        context.coordinator.next = next
        KeyboardDismissAccessory.configureDismissal(for: textField, next: next)
        DispatchQueue.main.async {
            if isFocused && !textField.isFirstResponder {
                textField.becomeFirstResponder()
            } else if !isFocused && textField.isFirstResponder {
                textField.resignFirstResponder()
            }
        }
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool
        let maxLength: Int?
        var next: (() -> Void)?
        
        init(text: Binding<String>, isFocused: Binding<Bool>, maxLength: Int?, next: (() -> Void)?) {
            self._text = text
            self._isFocused = isFocused
            self.maxLength = maxLength
            self.next = next
        }
        
        @objc fileprivate func textChanged(_ textField: UITextField) {
            let text = textField.text ?? ""
            DispatchQueue.main.async {
                self.text = text
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async { [weak textField] in
                textField?.selectedTextRange = textField?.textRange(from: textField!.endOfDocument, to: textField!.endOfDocument)
            }
            withAnimation {
                isFocused = true
            }
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let next {
                next()
            } else {
                textField.resignFirstResponder()
            }
            return true
        }

        func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
            if isFocused {
                isFocused = false
            }
            return true
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let maxLength = maxLength else {
                return true
            }
            let currentString: NSString = (textField.text ?? "") as NSString
            let newString: NSString = currentString.replacingCharacters(in: range, with: string) as NSString
            return newString.length <= maxLength
        }
    }
}
