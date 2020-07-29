//
//  Environment+ColorPalette.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-29.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

private struct ColorPaletteKey: EnvironmentKey {
    static var defaultValue: ColorPalette? = nil
}

public extension EnvironmentValues {
    var colorPalette: ColorPalette? {
        get { self[ColorPaletteKey.self] }
        set { self[ColorPaletteKey.self] = newValue }
    }
}
