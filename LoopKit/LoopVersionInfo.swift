//
//  LoopVersionInfo.swift
//  LoopKit
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

public enum VersionUpdate: Comparable {
    case noneNeeded, supportedNeeded, criticalNeeded
}

extension VersionUpdate {
    public var localizedDescription: String {
        switch self {
        case .noneNeeded:
            return NSLocalizedString("No Update Needed", comment: "Description of no software update needed")
        case .supportedNeeded:
            return NSLocalizedString("Supported Update Needed", comment: "Description of supported software update needed")
        case .criticalNeeded:
            return NSLocalizedString("Critical Update Needed", comment: "Description of critical software update needed")
        }
    }
}

public struct LoopVersionInfo {
    public let minimumSupported: String?
    public let criticalUpdateNeeded: [String]?
    
    public init(minimumSupported: String?, criticalUpdateNeeded: [String]?) {
        self.minimumSupported = minimumSupported
        self.criticalUpdateNeeded = criticalUpdateNeeded
    }
    
    public func needsVersionUpdate(currentVersion version: String) -> VersionUpdate {
        if needsCriticalUpdate(version: version) {
            return .criticalNeeded
        }
        if needsSupportedUpdate(version: version) {
            return .supportedNeeded
        }
        return .noneNeeded
    }
    
    public func needsCriticalUpdate(version: String) -> Bool {
        return criticalUpdateNeeded?.contains(version) ?? false
    }
    
    public func needsSupportedUpdate(version: String) -> Bool {
        guard let minimumSupported = minimumSupported,
              let minimumSupportedVersion = SemanticVersion(minimumSupported),
              let thisVersion = SemanticVersion(version) else {
            return false
        }
        return thisVersion < minimumSupportedVersion
    }
}
