//
//  DeviceStatusHighlight+Color.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-06.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

extension DeviceStatusHighlight {
    public var image: UIImage {
        return UIImage(systemName: imageSystemName)!
    }
    
    public var color: UIColor {
        switch state {
        case .normalCGM:
            return .glucose
        case .normalPump:
            return .insulin
        case .warning:
            return .warning
        case .critical:
            return .critical
        }
    }
}
