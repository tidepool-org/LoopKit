//
//  VersionCheckService.swift
//  LoopKit
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

// Note: order is important for VersionUpdate.  Later version updates are more critical than earlier ones.  Do not reorder!
public enum VersionUpdate: Comparable, CaseIterable {
    /// No version update needed.
    case none
    /// A update is available, but it is just informational (supported update).
    case available
    /// The version is unsupported; the app needs to be updated to the latest "supported" version.  Not a critical update.
    case recommended
    /// The app must be updated immediately.
    case required
}

extension VersionUpdate: RawRepresentable {
    public typealias RawValue = String
    public init?(rawValue: RawValue) {
        switch rawValue {
        case "none": self = .none
        case "available": self = .available
        case "recommended": self = .recommended
        case "required": self = .required
        default: return nil
        }
    }
    public var rawValue: RawValue {
        switch self {
        case .none: return "none"
        case .available: return "available"
        case .recommended: return "recommended"
        case .required:  return "required"
        }
    }
}

extension VersionUpdate {
    public static let `default` = VersionUpdate.none

    public var softwareUpdateAvailable: Bool { self > .none }
}

extension VersionUpdate {
    public var localizedDescription: String {
        switch self {
        case .none:
            return NSLocalizedString("No Update", comment: "Description of no software update needed")
        case .available:
            return NSLocalizedString("Update Available", comment: "Description of informational software update needed")
        case .recommended:
            return NSLocalizedString("Recommended Update", comment: "Description of supported software update needed")
        case .required:
            return NSLocalizedString("Critical Update", comment: "Description of critical software update needed")
        }
    }
}

public protocol VersionCheckService: Service {

    /**
     Check whether the given app version for the given `bundleIdentifier` needs an update.  Services should return their last result, if known.

     - Parameter bundleIdentifier: The calling app's `bundleIdentifier` (a.k.a. `CFBundleIdentifier`) string.
     - Parameter currentVersion: The current version to check.
     - Parameter completion: The completion function to call with any success result (or `nil` if not known) or failure.  
     */
    func checkVersion(bundleIdentifier: String, currentVersion: String, completion: @escaping (Result<VersionUpdate?, Error>) -> Void)
}

public extension Notification.Name {
    static let SoftwareUpdateAvailable = Notification.Name(rawValue: "com.loopkit.Loop.SoftwareUpdateAvailable")
}
