//
//  DeviceMessageState.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-23.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

public enum DeviceMessageState: Int, CaseIterable, Codable {
    case actionRequired
    case bluetoothOff
    case calibration
    case critical
    case searchingForDevice
    case unknown
    case waiting

    public var icon: UIImage? {
        guard #available(watchOSApplicationExtension 6.0, *) else {
            return nil
        }

        switch self {
        case .actionRequired:
            return UIImage(systemName: "plus.circle")!
        case .bluetoothOff:
            // TODO need a bluetooth symbol (does Bluetooth allow us to display their symbol?)
            return UIImage(systemName: "wifi.slash")!
        case .calibration:
            // TODO the calibration symbol shoud be a drop in filled circle
            return UIImage(systemName: "drop.triangle.fill")!
        case .critical:
            return UIImage(systemName: "exclamationmark.circle.fill")!
        case .searchingForDevice:
            return UIImage(systemName: "dot.radiowaves.left.and.right")!
        case .unknown:
            return UIImage(systemName: "questionmark.circle")!
        case .waiting:
            return UIImage(systemName: "clock")!
        }
    }
}
