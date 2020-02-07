//
//  SetupTableFooterView.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

open class SetupTableFooterView: UIView {

    public let primaryButton: SetupButton?

    public let secondaryButton: SetupButton?

    public let destructiveButton: SetupButton?

    public let cancelButton: SetupButton?

    public convenience override init(frame: CGRect) {
        let primaryButton = SetupButton(type: .custom)
        primaryButton.defaultTitle()
        self.init(frame: frame, primaryButton: primaryButton)
    }
    
    public init(frame: CGRect,
                primaryButton: SetupButton? = nil,
                secondaryButton: SetupButton? = nil,
                destructiveButton: SetupButton? = nil,
                cancelButton: SetupButton? = nil) {
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.destructiveButton = destructiveButton
        self.cancelButton = cancelButton
        
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth]

        primaryButton?.setTintColor(.systemBlue)
        secondaryButton?.setTintColor(.systemBlue, forBorderOnly: true)
        destructiveButton?.setTintColor(.destructive)
        cancelButton?.setTintColor(.destructive, forBorderOnly: true)

        let buttons = [primaryButton, secondaryButton, destructiveButton, cancelButton].compactMap { $0 }
        
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
