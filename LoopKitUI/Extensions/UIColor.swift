//
//  UIColor.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
import UIKit

private class FrameworkBundle {
    static let main = Bundle(for: FrameworkBundle.self)
}

private func BundleColor(_ name: String, compatibleWith traitCollection: UITraitCollection? = nil) -> UIColor? {
    return UIColor(named: name, in: FrameworkBundle.main, compatibleWith: traitCollection)
}

extension UIColor {
    static let destructive = critical
    static let invalid = critical    
}

extension UIColor {
    static func interpolatingBetween(_ first: UIColor, _ second: UIColor, biasTowardSecondColor bias: CGFloat = 0.5) -> UIColor {
        let (r1, g1, b1, a1) = first.components
        let (r2, g2, b2, a2) = second.components
        return UIColor(
            red: (r2 - r1) * bias + r1,
            green: (g2 - g1) * bias + g1,
            blue: (b2 - b1) * bias + b1,
            alpha: (a2 - a1) * bias + a1
        )
    }

    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r, g, b, a: CGFloat
        (r, g, b, a) = (0, 0, 0, 0)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - UIColor palette for common elements

/// The intent in providing these suggested context specific colors is to inform the user of the related context of the UI. Note loopAccent is intended to be use as the app accent colour.
extension UIColor {    
    @nonobjc public static let axisLabelColor = secondaryLabel
    
    @nonobjc public static let axisLineColor = clear
    
    @nonobjc public static let carbs = BundleColor("carbs") ?? systemGreen

    @nonobjc public static let critical = BundleColor("critical") ?? systemRed

    @nonobjc public static let glucose = BundleColor("glucose") ?? systemBlue

    @nonobjc public static let gridColor = systemGray3
    
    @nonobjc public static let insulin = BundleColor("insulin") ?? systemOrange

    @nonobjc public static let loopAccent = BundleColor("accent") ?? systemBlue
    
    @nonobjc public static let warning = BundleColor("warning") ?? systemYellow
}

// MARK: - Context for colors
extension UIColor {
    public static let cobTintColor = carbs

    public static let doseTintColor = insulin

    public static let glucoseTintColor = glucose

    public static let iobTintColor = insulin
}
