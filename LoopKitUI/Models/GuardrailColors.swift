//
//  GuardrailColors.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-31.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct GuardrailColors {
    public var inRange: Color
    public var warning: Color
    public var critical: Color
    
    public init(inRange: Color = .primary,
                warning: Color = .warning,
                critical: Color = .critical)
    {
        self.inRange = inRange
        self.warning = warning
        self.critical = critical
    }
}
