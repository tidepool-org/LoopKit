//
//  DeviceLifecycleProgressState+Color.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-03.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

extension DeviceLifecycleProgressState {
    public var color: UIColor {
        switch self {
        case .normal:
            return .systemPurple
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }
}


extension DeviceStatusHighlight {
    public var image: UIImage {
        return UIImage(systemName: imageSystemName)!
    }
    
    public var color: UIColor {
        switch state {
        case .normal:
            return .systemPurple
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }
}
