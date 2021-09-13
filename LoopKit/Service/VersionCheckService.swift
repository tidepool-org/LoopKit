//
//  VersionCheckService.swift
//  LoopKit
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol VersionCheckService: Service {

    /**
     Check whether the given app version for the given `bundleIdentifier` needs an update.

     - Parameter bundleIdentifier: The calling app's `bundleIdentifier` (a.k.a. `CFBundleIdentifier`) string.
     - Parameter currentVersion: The current version to check.
     - Parameter completion: The completion function to call with any success result or failure.
     */
    func checkVersion(bundleIdentifier: String, currentVersion: String, completion: @escaping (Result<VersionUpdate, Error>) -> Void)
}
