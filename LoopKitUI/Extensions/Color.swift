//
//  Color.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-03-04.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

// MARK: - Color palette for common elements
/// The intent in providing these suggested context specific colors is to inform the user of the related context of the UI. Note loopAccent is intended to be use as the app accent colour.
extension Color {
    public static let axisLabelColor = Color(UIColor.axisLabelColor)
    
    public static let axisLineColor = Color(UIColor.axisLineColor)
    
    public static let carbs = Color(UIColor.carbs)

    public static let critical = Color(UIColor.critical)

    public static let glucose = Color(UIColor.glucose)
    
    public static let gridColor = Color(UIColor.gridColor)

    public static let insulin = Color(UIColor.insulin)

    public static let loopAccent = Color(UIColor.loopAccent)

    public static let warning = Color(UIColor.warning)
}

// MARK: - Context for colors
extension Color {
    public static let cobTintColor = carbs

    public static let destructive = Color(UIColor.destructive)

    public static let doseTintColor = insulin

    public static let glucoseTintColor = glucose

    public static let instructionalContent = Color.secondary

    public static let invalid = Color(UIColor.invalid)

    public static let iobTintColor = insulin
}
