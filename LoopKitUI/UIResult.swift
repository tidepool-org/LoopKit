//
//  UIResult.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 1/21/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

public enum UIResult<UserInteractionRequired, Success, Failure> where Failure: Error {
    case userInteractionRequired(UserInteractionRequired)
    case success(Success)
    case failure(Failure)
}
