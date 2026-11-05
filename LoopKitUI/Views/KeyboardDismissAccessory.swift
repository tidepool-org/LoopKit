//
//  KeyboardDismissAccessory.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import UIKit

/// The trailing button above the keyboard, shared by SwiftUI and UIKit fields.
enum KeyboardToolbarButton {
    case done
    case next

    init(hasNext: Bool) {
        self = hasNext ? .next : .done
    }

    var title: String {
        switch self {
        case .done:
            return LocalizedString("Done", comment: "Keyboard toolbar button that dismisses the keyboard")
        case .next:
            return LocalizedString("Next", comment: "Keyboard toolbar button that moves to the next field")
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .done:
            return "button_KeyboardDone"
        case .next:
            return "button_KeyboardNext"
        }
    }
}

private protocol KeyboardActionAccessory: UIView {
    func update(for textField: UITextField, next: (() -> Void)?)
}

private final class KeyboardAction {
    weak var textField: UITextField?
    var next: (() -> Void)?

    var kind: KeyboardToolbarButton {
        KeyboardToolbarButton(hasNext: next != nil)
    }

    func perform() {
        if let next {
            next()
        } else {
            textField?.resignFirstResponder()
        }
    }
}

public enum KeyboardDismissAccessory {
    @available(iOS 26.0, *)
    private final class KeyboardActionBar: UIView, KeyboardActionAccessory {
        private static let horizontalPadding: CGFloat = 16
        private static let verticalPadding: CGFloat = 8

        private let action = KeyboardAction()
        private let button = UIButton(type: .system)

        init(for textField: UITextField, next: (() -> Void)?) {
            super.init(frame: .zero)
            autoresizingMask = .flexibleHeight
            backgroundColor = .clear

            button.translatesAutoresizingMaskIntoConstraints = false
            button.addAction(UIAction { [weak self] _ in self?.action.perform() }, for: .primaryActionTriggered)
            addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: topAnchor, constant: Self.verticalPadding),
                button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.verticalPadding),
                button.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -Self.horizontalPadding),
            ])

            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (bar: KeyboardActionBar, _: UITraitCollection) in
                bar.invalidateIntrinsicContentSize()
            }

            update(for: textField, next: next)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: button.intrinsicContentSize.height + 2 * Self.verticalPadding)
        }

        // Like the SwiftUI bar's spacer, the empty strip beside the button doesn't take touches.
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let view = super.hitTest(point, with: event)
            return view === self ? nil : view
        }

        func update(for textField: UITextField, next: (() -> Void)?) {
            action.textField = textField
            action.next = next

            guard button.configuration?.title != action.kind.title else { return }
            button.accessibilityIdentifier = action.kind.accessibilityIdentifier
            var configuration = UIButton.Configuration.glass()
            configuration.title = action.kind.title
            configuration.baseForegroundColor = .label
            configuration.buttonSize = .medium
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: UIFont.labelFontSize, weight: .semibold))
                return attributes
            }
            button.configuration = configuration
            invalidateIntrinsicContentSize()
        }
    }

    private final class KeyboardActionToolbar: UIToolbar, KeyboardActionAccessory {
        private let action = KeyboardAction()
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
            tintColor = action.textField?.tintColor
        }

        func update(for textField: UITextField, next: (() -> Void)?) {
            action.textField = textField
            action.next = next
            tintColor = textField.tintColor

            let showsNextButton = next != nil
            guard showsNextButton != self.showsNextButton else { return }
            self.showsNextButton = showsNextButton

            let button = UIBarButtonItem(title: action.kind.title, style: .done, target: self, action: #selector(tapped))
            button.accessibilityIdentifier = action.kind.accessibilityIdentifier
            items = [UIBarButtonItem(systemItem: .flexibleSpace), button]
        }

        @objc private func tapped() {
            action.perform()
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
        if let accessory = textField.inputAccessoryView as? KeyboardActionAccessory {
            accessory.update(for: textField, next: next)
            return
        }
        if #available(iOS 26.0, *) {
            textField.inputAccessoryView = KeyboardActionBar(for: textField, next: next)
        } else {
            textField.inputAccessoryView = KeyboardActionToolbar(for: textField, next: next)
        }
        if textField.isFirstResponder { textField.reloadInputViews() }
    }
}
