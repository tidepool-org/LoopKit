//
//  KeyboardDismissAccessory.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import UIKit

public enum KeyboardDismissAccessory {
    private final class KeyboardActionToolbar: UIToolbar {
        private weak var textField: UITextField?
        private var nextAction: (() -> Void)?
        private var showsNextButton: Bool?

        init(for textField: UITextField, next: (() -> Void)?) {
            super.init(frame: .zero)
            autoresizingMask = .flexibleWidth
            update(for: textField, next: next)
            sizeToFit()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyTint()
        }

        private func applyTint() {
            if #available(iOS 26.0, *) {
                tintColor = .label
            } else {
                tintColor = textField?.tintColor
            }
        }

        func update(for textField: UITextField, next: (() -> Void)?) {
            self.textField = textField
            self.nextAction = next
            applyTint()

            let showsNextButton = next != nil
            guard showsNextButton != self.showsNextButton else { return }
            self.showsNextButton = showsNextButton

            let title = showsNextButton
                ? LocalizedString("Next", comment: "Title of the keyboard toolbar button that moves to the next field")
                : LocalizedString("Done", comment: "Title of the keyboard toolbar button that dismisses the keyboard")
            let button: UIBarButtonItem
            if #available(iOS 26.0, *) {
                button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(tapped))
                let font = UIFont.systemFont(ofSize: UIFont.labelFontSize, weight: .semibold)
                button.setTitleTextAttributes([.font: font], for: .normal)
                button.setTitleTextAttributes([.font: font], for: .highlighted)
            } else {
                button = UIBarButtonItem(title: title, style: .done, target: self, action: #selector(tapped))
            }
            items = [UIBarButtonItem(systemItem: .flexibleSpace), button]
        }

        @objc private func tapped() {
            if let nextAction {
                nextAction()
            } else {
                textField?.resignFirstResponder()
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

    public static func configureDismissal(for textField: UITextField, next: (() -> Void)? = nil) {
        if hasReturnKey(textField) {
            let returnKeyType: UIReturnKeyType = next == nil ? .done : .next
            if textField.returnKeyType != returnKeyType {
                textField.returnKeyType = returnKeyType
            }
        }
        if let toolbar = textField.inputAccessoryView as? KeyboardActionToolbar {
            toolbar.update(for: textField, next: next)
            return
        }
        textField.inputAccessoryView = KeyboardActionToolbar(for: textField, next: next)
        if textField.isFirstResponder { textField.reloadInputViews() }
    }
}
