//
//  Environment+Colors.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-29.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

private struct WarningColorKey: EnvironmentKey {
    static var defaultValue: Color = .yellow
}

public extension EnvironmentValues {
    var warningColor: Color {
        get { self[WarningColorKey.self] }
        set { self[WarningColorKey.self] = newValue }
    }
}

private struct COBTintColorKey: EnvironmentKey {
    static var defaultValue: Color = .green
}

public extension EnvironmentValues {
    var cobTintColor: Color {
        get { self[COBTintColorKey.self] }
        set { self[COBTintColorKey.self] = newValue }
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
