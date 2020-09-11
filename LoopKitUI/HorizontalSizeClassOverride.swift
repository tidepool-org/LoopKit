//
//  HorizontalSizeClassOverride.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 6/5/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public protocol HorizontalSizeClassOverride {
    var horizontalOverride: UserInterfaceSizeClass { get }
}

public extension HorizontalSizeClassOverride {
    // iPod Touch and iPhone SE 1st generation are considered to have a short display
    static var shortDisplayLimit: CGFloat {
        return 640
    }
    
    // iPod Touch and iPhone SE 1st Generation are considered to have a narrow display
    static var narrowDisplayLimit: CGFloat {
        return 370
    }
    
    
    var horizontalOverride: UserInterfaceSizeClass {
        if UIScreen.main.bounds.height <= Self.shortDisplayLimit {
            return .compact
        } else {
            return .regular
        }
    }
        
    var isDisplayNarrow: Bool {
        if UIScreen.main.bounds.width <= Self.narrowDisplayLimit {
            return true
        } else {
            return false
        }
    }
}
