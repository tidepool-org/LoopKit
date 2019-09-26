//
//  MockService+UI.swift
//  MockKitUI
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import MockKit


extension MockService: ServiceUI {

    public static func setupViewController() -> (UIViewController & ServiceNotifying & CompletionNotifying)? {
        return ServiceViewController(rootViewController: MockServiceTableViewController(mockService: MockService(), for: .create))
    }

    public func settingsViewController() -> (UIViewController & ServiceNotifying & CompletionNotifying) {
      return ServiceViewController(rootViewController: MockServiceTableViewController(mockService: self, for: .update))
    }
    
}
