//
//  UIImage.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-15.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

extension UIImage {
    convenience init?(frameworkImage name: String) {
        self.init(named: name, in: FrameworkBundle.main, with: nil)
    }
}
