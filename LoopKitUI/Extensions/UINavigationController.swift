//
//  UINavigationController.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

extension UINavigationController {
    public func groupedTableViewHiddenNavBarStyle() {
        self.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationBar.backgroundColor = .loopGroupTableViewBackground
        self.navigationBar.shadowImage = UIImage()
    }
    
    public func groupedTableViewNavBarStyle() {
        self.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationBar.backgroundColor = .loopGroupTableViewBackground
    }
}

