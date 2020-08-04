//
//  Environment+Colors.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-29.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

private struct GuardrailColorsKey: EnvironmentKey {
    static var defaultValue: GuardrailColors = GuardrailColors()
}

public extension EnvironmentValues {
    var guardrailColors: GuardrailColors {
        get { self[GuardrailColorsKey.self] }
        set { self[GuardrailColorsKey.self] = newValue }
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
