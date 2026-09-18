//
//  DismissibleKeyboardTextField.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct DismissibleKeyboardTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: UIFont
    var textColor: UIColor
    var textAlignment: NSTextAlignment
    var keyboardType: UIKeyboardType
    var autocapitalizationType: UITextAutocapitalizationType
    var autocorrectionType: UITextAutocorrectionType
    var shouldBecomeFirstResponder: Bool
    var maxLength: Int?
    var doneButtonColor: UIColor
    var isDismissible: Bool
    var textFieldDidBeginEditing: (() -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        textAlignment: NSTextAlignment = .natural,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        autocorrectionType: UITextAutocorrectionType = .default,
        shouldBecomeFirstResponder: Bool = false,
        maxLength: Int? = nil,
        doneButtonColor: UIColor = .blue,
        isDismissible: Bool = true,
        textFieldDidBeginEditing: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.keyboardType = keyboardType
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.maxLength = maxLength
        self.doneButtonColor = doneButtonColor
        self.isDismissible = isDismissible
        self.textFieldDidBeginEditing = textFieldDidBeginEditing
    }

    public func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingDidBegin), for: .editingDidBegin)
        textField.delegate = context.coordinator
        textField.accessibilityIdentifier = "dismissibleKeyboardTextField"
        return textField
    }

    public func updateUIView(_ textField: UITextField, context: Context) {
        textField.text = text
        textField.placeholder = placeholder
        textField.font = font
        textField.textColor = textColor
        textField.textAlignment = textAlignment
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = autocorrectionType
        if isDismissible {
            KeyboardDismissAccessory.configureDismissal(for: textField)
        }

        if shouldBecomeFirstResponder && !context.coordinator.didBecomeFirstResponder {
            // See https://developer.apple.com/documentation/uikit/uiresponder/1621113-becomefirstresponder for why
            // we check the window property here (otherwise it might crash)
            if textField.window != nil && textField.becomeFirstResponder() {
                context.coordinator.didBecomeFirstResponder = true
            }
        } else if !shouldBecomeFirstResponder && context.coordinator.didBecomeFirstResponder {
            if textField.isFirstResponder {
                textField.resignFirstResponder()
            }
            context.coordinator.didBecomeFirstResponder = false
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self, maxLength: maxLength)
    }

    public final class Coordinator: NSObject {
        var parent: DismissibleKeyboardTextField
        let maxLength: Int?

        // Track in the coordinator to ensure the text field only becomes first responder once,
        // rather than on every state change.
        var didBecomeFirstResponder = false

        init(_ parent: DismissibleKeyboardTextField, maxLength: Int?) {
            self.parent = parent
            self.maxLength = maxLength
        }

        @objc fileprivate func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        @objc fileprivate func editingDidBegin(_ textField: UITextField) {
            // Even though we are likely already on .main, we still need to queue this cursor (selection) change in
            // order for it to work
            DispatchQueue.main.async {
                textField.moveCursorToEnd()
            }
        }
    }
}

public enum KeyboardDismissAccessory {
    static let height: CGFloat = 52

    final class Strip: UIInputView {}

    public static func wantsStrip(_ textField: UITextField) -> Bool {
        if textField.inputView != nil || textField.inputViewController != nil { return true }
        switch textField.keyboardType {
        case .numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad:
            return true
        default:
            return false
        }
    }

    public static func configureDismissal(for textField: UITextField) {
        if wantsStrip(textField) {
            guard !(textField.inputAccessoryView is Strip) else { return }
            textField.inputAccessoryView = make(dismissing: textField)
            if textField.isFirstResponder { textField.reloadInputViews() }
        } else {
            if textField.inputAccessoryView is Strip {
                textField.inputAccessoryView = nil
                if textField.isFirstResponder { textField.reloadInputViews() }
            }
            textField.returnKeyType = .done
        }
    }

    public static func make(dismissing responder: UIResponder) -> UIView {
        let strip = Strip(
            frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height),
            inputViewStyle: .keyboard
        )
        strip.allowsSelfSizing = true
        strip.autoresizingMask = .flexibleWidth

        var configuration: UIButton.Configuration
        if #available(iOS 26.0, *) {
            configuration = .glass()
        } else {
            configuration = .plain()
        }
        configuration.title = LocalizedString("Done", comment: "Title of the keyboard toolbar button that dismisses the keyboard")
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline)
            return attributes
        }
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        let dismissButton = UIButton(configuration: configuration)
        dismissButton.accessibilityHint = LocalizedString("Dismisses the keyboard", comment: "Accessibility hint for the keyboard toolbar Done button")
        dismissButton.addTarget(responder, action: #selector(UIResponder.resignFirstResponder), for: .touchUpInside)

        strip.addSubview(dismissButton)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            strip.heightAnchor.constraint(equalToConstant: height),
            dismissButton.trailingAnchor.constraint(equalTo: strip.layoutMarginsGuide.trailingAnchor),
            dismissButton.centerYAnchor.constraint(equalTo: strip.centerYAnchor),
        ])
        return strip
    }
}

extension DismissibleKeyboardTextField.Coordinator: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let maxLength = maxLength else {
            return true
        }
        let currentString: NSString = (textField.text ?? "") as NSString
        let newString: NSString =
            currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        parent.textFieldDidBeginEditing?()
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.returnKeyType == .done {
            textField.resignFirstResponder()
        }
        return true
    }
}
