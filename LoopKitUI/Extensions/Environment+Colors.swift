//
//  Environment+Colors.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-29.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

private struct GuidanceColorsKey: EnvironmentKey {
    static var defaultValue: GuidanceColors = GuidanceColors()
}

public extension EnvironmentValues {
    var guidanceColors: GuidanceColors {
        get { self[GuidanceColorsKey.self] }
        set { self[GuidanceColorsKey.self] = newValue }
    }
}

private struct CarbTintColorKey: EnvironmentKey {
    static var defaultValue: Color = .green
}

public extension EnvironmentValues {
    var carbTintColor: Color {
        get { self[CarbTintColorKey.self] }
        set { self[CarbTintColorKey.self] = newValue }
    }
}

private struct GlucoseTintColorKey: EnvironmentKey {
    static var defaultValue: Color = Color(.systemTeal)
}

public extension EnvironmentValues {
    var glucoseTintColor: Color {
        get { self[GlucoseTintColorKey.self] }
        set { self[GlucoseTintColorKey.self] = newValue }
    }
}
