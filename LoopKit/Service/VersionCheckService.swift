//
//  VersionCheckService.swift
//  LoopKit
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol VersionCheckService: Service {

    func checkVersion(currentVersion: String, completion: @escaping (Result<VersionUpdate, Error>) -> Void)
}
