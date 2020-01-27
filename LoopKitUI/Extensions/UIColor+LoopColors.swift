//
//  UIColor+LoopColors.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

extension UIColor {
    public static var loopSelectable: UIColor {
        return .systemBlue
    }
    
    public static var loopSelected: UIColor {
        return .systemBlue
    }
    
    public static var loopNumbering: UIColor {
        return .systemBlue
    }
    
    public static var loopDim: UIColor {
        if #available(iOSApplicationExtension 13.0, *) {
            return .secondaryLabel
        } else {
            return .systemGray
        }
    }
    
    public static var loopDestructive: UIColor {
        return .systemRed
    }
    
    public static var loopLabel: UIColor {
        if #available(iOSApplicationExtension 13.0, *) {
            return .label
        } else {
            return .black
        }
    }
    
    public static var loopGroupTableViewBackground: UIColor {
        if #available(iOSApplicationExtension 13.0, *) {
            return .systemGroupedBackground
        } else {
            return .groupTableViewBackground
        }
    }
}
