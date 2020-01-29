//
//  MultiButtonTableFooterView.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

public class MultiButtonTableFooterView: UIView {

    public let primaryButton: TableFooterButton?

    public let secondaryButton: TableFooterButton?

    public let destructiveButton: TableFooterButton?

    public let cancelButton: TableFooterButton?

    public init(frame: CGRect,
                primaryButton: TableFooterButton? = nil,
                secondaryButton: TableFooterButton? = nil,
                destructiveButton: TableFooterButton? = nil,
                cancelButton: TableFooterButton? = nil) {
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.destructiveButton = destructiveButton
        self.cancelButton = cancelButton
        
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth]

        primaryButton?.setStyle(forColor: .loopSelectable)
        secondaryButton?.setStyle(forColor: .loopSelectable, borderOnly: true)
        destructiveButton?.setStyle(forColor: .loopDestructive)
        cancelButton?.setStyle(forColor: .loopDestructive, borderOnly: true)

        var buttons: [TableFooterButton] = []
        if let primaryButton = primaryButton {
            buttons.append(primaryButton)
        }
        if let secondaryButton = secondaryButton {
            buttons.append(secondaryButton)
        }
        if let destructiveButton = destructiveButton {
            buttons.append(destructiveButton)
        }
        if let cancelButton = cancelButton {
            buttons.append(cancelButton)
        }
        
        let buttonStack = UIStackView(arrangedSubviews: buttons)
        buttonStack.alignment = .center
        buttonStack.axis = .vertical
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.spacing = 10
        
        addSubview(buttonStack)

        var constraints = [
            buttonStack.topAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.topAnchor),
            buttonStack.leadingAnchor.constraint(equalToSystemSpacingAfter: layoutMarginsGuide.leadingAnchor, multiplier: 1),
            layoutMarginsGuide.trailingAnchor.constraint(equalToSystemSpacingAfter: buttonStack.trailingAnchor, multiplier: 1),
            safeAreaLayoutGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: buttonStack.bottomAnchor, multiplier: 1),
        ]
        for button in buttons {
            constraints.append(contentsOf: [
                button.leadingAnchor.constraint(equalTo: buttonStack.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: buttonStack.trailingAnchor),
            ])
        }
        NSLayoutConstraint.activate(constraints)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
