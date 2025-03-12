//
//  Environment+TherapySettings.swift
//  LoopKit
//
//  Created by Pete Schwamb on 2/25/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

private struct TherapySettingsKey: EnvironmentKey {
    static let defaultValue = TherapySettings.init()
}

public extension EnvironmentValues {
    var therapySettings: TherapySettings {
        get { self[TherapySettingsKey.self] }
        set { self[TherapySettingsKey.self] = newValue }
    }
}
