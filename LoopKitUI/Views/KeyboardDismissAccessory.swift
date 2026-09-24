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
            tintColor = textField?.tintColor
        }

        func update(for textField: UITextField, next: (() -> Void)?) {
            let needsUpdatedItems = items == nil || (nextAction == nil) != (next == nil)
            self.textField = textField
            self.nextAction = next
            if tintColor != textField.tintColor {
                tintColor = textField.tintColor
            }
            // Replacing identical items during a SwiftUI update can trigger another layout.
            // Always refresh the callback, but rebuild the toolbar only when its label changes.
            guard needsUpdatedItems else { return }

            let button: UIBarButtonItem
            if next != nil {
                button = UIBarButtonItem(
                    title: LocalizedString("Next", comment: "Title of the keyboard toolbar button that moves to the next field"),
                    style: .done,
                    target: self,
                    action: #selector(tapped)
                )
            } else {
                button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(tapped))
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
