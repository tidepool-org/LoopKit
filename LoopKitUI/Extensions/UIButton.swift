//
//  UIButton.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-03.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

extension UIButton {
    public func setTintColor(_ color: UIColor, forBorderOnly: Bool = false) {
        if forBorderOnly {
            self.tintColor = .clear
            self.layer.cornerRadius = 5
            self.layer.borderWidth = 1
            self.layer.borderColor = color.cgColor
            self.setTitleColor(color, for: .normal)
        } else {
            self.tintColor = color
        }
    }
}
