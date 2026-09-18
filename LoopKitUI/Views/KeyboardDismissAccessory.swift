//
//  KeyboardDismissAccessory.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import UIKit

public enum KeyboardDismissAccessory {
    static let minimumHitTarget: CGFloat = 44
    static let verticalSpacing: CGFloat = 8
    static let horizontalSpacing: CGFloat = 16
    static let horizontalContentInset: CGFloat = 14
    static let verticalContentInset: CGFloat = 6
    static let height = minimumHitTarget + 2 * verticalSpacing

    private final class AccessoryButton: UIButton {
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let horizontalExpansion = max(0, (KeyboardDismissAccessory.minimumHitTarget - bounds.width) / 2)
            let verticalExpansion = max(0, (KeyboardDismissAccessory.minimumHitTarget - bounds.height) / 2)
            return bounds.insetBy(dx: -horizontalExpansion, dy: -verticalExpansion).contains(point)
        }
    }

    final class Strip: UIInputView {
        private weak var textField: UITextField?
        private let button: UIButton
        private var nextAction: (() -> Void)?

        init(for textField: UITextField, next: (() -> Void)?) {
            var configuration: UIButton.Configuration
            if #available(iOS 26.0, *) {
                configuration = .glass()
            } else {
                configuration = .plain()
            }
            configuration.baseForegroundColor = .label
            configuration.cornerStyle = .capsule
            configuration.buttonSize = .small
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: KeyboardDismissAccessory.verticalContentInset,
                leading: KeyboardDismissAccessory.horizontalContentInset,
                bottom: KeyboardDismissAccessory.verticalContentInset,
                trailing: KeyboardDismissAccessory.horizontalContentInset
            )
            button = AccessoryButton(configuration: configuration)

            super.init(
                frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: KeyboardDismissAccessory.height),
                inputViewStyle: .keyboard
            )
            allowsSelfSizing = true
            autoresizingMask = .flexibleWidth
            directionalLayoutMargins = NSDirectionalEdgeInsets(
                top: 0,
                leading: KeyboardDismissAccessory.horizontalSpacing,
                bottom: 0,
                trailing: KeyboardDismissAccessory.horizontalSpacing
            )

            button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
            addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                heightAnchor.constraint(greaterThanOrEqualToConstant: KeyboardDismissAccessory.height),
                button.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
                button.leadingAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor),
                button.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: KeyboardDismissAccessory.verticalSpacing),
                button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -KeyboardDismissAccessory.verticalSpacing),
            ])
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (strip: Strip, _: UITraitCollection) in
                strip.updateButtonFont()
                if strip.textField?.isFirstResponder == true {
                    strip.textField?.reloadInputViews()
                }
            }
            updateButtonFont()
            update(for: textField, next: next)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override var intrinsicContentSize: CGSize {
            CGSize(
                width: UIView.noIntrinsicMetric,
                height: max(KeyboardDismissAccessory.minimumHitTarget, button.intrinsicContentSize.height)
                    + 2 * KeyboardDismissAccessory.verticalSpacing
            )
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

        func update(for textField: UITextField, next: (() -> Void)?) {
            self.textField = textField
            self.nextAction = next
            var configuration = button.configuration
            configuration?.title = next == nil
                ? LocalizedString("Done", comment: "Title of the keyboard toolbar button that dismisses the keyboard")
                : LocalizedString("Next", comment: "Title of the keyboard toolbar button that moves to the next field")
            button.configuration = configuration
            button.accessibilityHint = next == nil
                ? LocalizedString("Dismisses the keyboard", comment: "Accessibility hint for the keyboard toolbar Done button")
                : LocalizedString("Moves to the next field", comment: "Accessibility hint for the keyboard toolbar Next button")
            invalidateIntrinsicContentSize()
            setNeedsLayout()
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
            textField.returnKeyType = next == nil ? .done : .next
        }
        if let strip = textField.inputAccessoryView as? Strip {
            strip.update(for: textField, next: next)
        } else {
            let strip = Strip(for: textField, next: next)
            textField.inputAccessoryView = strip
            if textField.isFirstResponder { textField.reloadInputViews() }
        }
    }
}
