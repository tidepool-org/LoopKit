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

    final class Strip: UIInputView {
        private weak var textField: UITextField?
        private let button: UIButton
        private var mirrorsReturnKey = false

        init(for textField: UITextField) {
            var configuration: UIButton.Configuration
            if #available(iOS 26.0, *) {
                configuration = .glass()
            } else {
                configuration = .plain()
            }
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.preferredFont(forTextStyle: .headline)
                return attributes
            }
            configuration.baseForegroundColor = .label
            configuration.cornerStyle = .capsule
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
            button = UIButton(configuration: configuration)

            super.init(
                frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: KeyboardDismissAccessory.height),
                inputViewStyle: .keyboard
            )
            allowsSelfSizing = true
            autoresizingMask = .flexibleWidth

            button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
            addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: KeyboardDismissAccessory.height),
                button.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
                button.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            update(for: textField)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func update(for textField: UITextField) {
            self.textField = textField
            mirrorsReturnKey = KeyboardDismissAccessory.hasReturnKey(textField)
                && !Self.isDismissing(textField.returnKeyType)
            var configuration = button.configuration
            configuration?.title = mirrorsReturnKey
                ? Self.title(for: textField.returnKeyType)
                : LocalizedString("Done", comment: "Title of the keyboard toolbar button that dismisses the keyboard")
            button.configuration = configuration
            button.accessibilityHint = mirrorsReturnKey
                ? nil
                : LocalizedString("Dismisses the keyboard", comment: "Accessibility hint for the keyboard toolbar Done button")
        }

        @objc private func tapped() {
            guard let textField else { return }
            if mirrorsReturnKey,
               let delegate = textField.delegate,
               delegate.responds(to: #selector(UITextFieldDelegate.textFieldShouldReturn(_:))) {
                _ = delegate.textFieldShouldReturn?(textField)
            } else {
                textField.resignFirstResponder()
            }
        }

        private static func isDismissing(_ type: UIReturnKeyType) -> Bool {
            type == .default || type == .done
        }

        private static func title(for type: UIReturnKeyType) -> String {
            switch type {
            case .next:
                return LocalizedString("Next", comment: "Title of the keyboard toolbar button that moves to the next field")
            case .continue:
                return LocalizedString("Continue", comment: "Title of the keyboard toolbar button that continues")
            case .go:
                return LocalizedString("Go", comment: "Title of the keyboard toolbar button that submits (Go)")
            case .search:
                return LocalizedString("Search", comment: "Title of the keyboard toolbar button that searches")
            case .send:
                return LocalizedString("Send", comment: "Title of the keyboard toolbar button that sends")
            case .join:
                return LocalizedString("Join", comment: "Title of the keyboard toolbar button that joins")
            default:
                return LocalizedString("Done", comment: "Title of the keyboard toolbar button that dismisses the keyboard")
            }
        }
    }

    static func hasReturnKey(_ textField: UITextField) -> Bool {
        if textField.inputView != nil || textField.inputViewController != nil { return false }
        switch textField.keyboardType {
        case .numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad:
            return false
        default:
            return true
        }
    }

    public static func configureDismissal(for textField: UITextField) {
        if hasReturnKey(textField), textField.returnKeyType == .default {
            textField.returnKeyType = .done
        }
        if let strip = textField.inputAccessoryView as? Strip {
            strip.update(for: textField)
        } else {
            textField.inputAccessoryView = make(for: textField)
            if textField.isFirstResponder { textField.reloadInputViews() }
        }
    }

    public static func make(for textField: UITextField) -> UIView {
        Strip(for: textField)
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
