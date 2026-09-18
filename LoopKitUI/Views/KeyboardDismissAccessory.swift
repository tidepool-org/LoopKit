//
//  KeyboardDismissAccessory.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import UIKit

public enum KeyboardDismissAccessory {
    static let height: CGFloat = 52

    final class Strip: UIInputView {
        private weak var textField: UITextField?
        private let button: UIButton

        init(for textField: UITextField) {
            var configuration: UIButton.Configuration
            if #available(iOS 26.0, *) {
                configuration = .glass()
            } else {
                configuration = .plain()
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
                heightAnchor.constraint(greaterThanOrEqualToConstant: KeyboardDismissAccessory.height),
                button.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
                button.leadingAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor),
                button.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 4),
                button.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),
                button.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (strip: Strip, _: UITraitCollection) in
                strip.updateButtonFont()
            }
            updateButtonFont()
            update(for: textField)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        private func updateButtonFont() {
            let font = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
            var configuration = button.configuration
            configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = font
                return attributes
            }
            button.configuration = configuration
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }

        func update(for textField: UITextField) {
            self.textField = textField
            var configuration = button.configuration
            configuration?.title = LocalizedString("Done", comment: "Title of the keyboard toolbar button that dismisses the keyboard")
            button.configuration = configuration
            button.accessibilityHint = LocalizedString("Dismisses the keyboard", comment: "Accessibility hint for the keyboard toolbar Done button")
        }

        @objc private func tapped() {
            textField?.resignFirstResponder()
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
            let strip = Strip(for: textField)
            strip.update(for: textField)
            textField.inputAccessoryView = strip
            if textField.isFirstResponder { textField.reloadInputViews() }
        }
    }
}
