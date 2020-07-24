//
//  Environment+Authenticate.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 8/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LocalAuthentication
import SwiftUI

public typealias Completion<Value> = (Result<Value, Error>) -> Void
public typealias AuthenticationChallenge = (_ description: String, _ completion: @escaping Completion<Void>) -> Void
public extension Result where Success == Void {
    static var success: Result {
        return Result.success(Void())
    }
}
public struct UnknownError: Swift.Error { }

private struct AuthenticationChallengeKey: EnvironmentKey {
    static let defaultValue: AuthenticationChallenge = { authenticationChallengeDescription, completion in
        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                   localizedReason: authenticationChallengeDescription,
                                   reply: { (success, error) in
                                    DispatchQueue.main.async {
                                        completion(success ? .success : .failure(error ?? UnknownError()))
                                    }
            })
        }
    }
}

extension EnvironmentValues {
    public var authenticate: AuthenticationChallenge {
        get { self[AuthenticationChallengeKey.self] }
        set { self[AuthenticationChallengeKey.self] = newValue }
    }
}
