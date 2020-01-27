//
//  UIFont.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-17.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

extension UIFont {
    public static var loopTitleFontGroupedInset: UIFont {
        return UIFontMetrics(forTextStyle: .title1).scaledFont(for: systemFont(ofSize: 28, weight: .semibold))
    }
    
    public static var loopSectionHeaderFontGroupedInset: UIFont {
        return UIFontMetrics(forTextStyle: .headline).scaledFont(for: systemFont(ofSize: 19, weight: .semibold))
    }
    
    public static var loopFootnote: UIFont {
        return preferredFont(forTextStyle: .footnote)
    }
    
    public static var loopInstructionTitle: UIFont {
        return preferredFont(forTextStyle: .headline)
    }
    
    public static var loopInstructionStep: UIFont {
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: systemFont(ofSize: 14))
    }
    
    public static var loopInstructionNumber: UIFont {
        return preferredFont(forTextStyle: .subheadline)
    }
    
    public static var loopInputValue: UIFont {
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: systemFont(ofSize: 48))
    }
    
    public static var loopBolded: UIFont {
        return .systemFont(ofSize: 17, weight: .bold)
    }
    
    public static var loopRegular: UIFont {
        return .systemFont(ofSize: 17)
    }
}
