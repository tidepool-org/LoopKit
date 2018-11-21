//
//  Collection.swift
//  LoopKit
//
//  Created by Michael Pangburn on 12/4/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Dispatch


extension Collection {
    func asyncMap<NewElement>(
        _ asyncTransform: (
            _ element: Element,
            _ completion: @escaping (NewElement) -> Void
        ) -> Void,
        completion: @escaping ([NewElement]) -> Void
    ) {
        let result = Locked(Array<NewElement?>(repeating: nil, count: count))
        let group = DispatchGroup()

        for (resultIndex, element) in enumerated() {
            group.enter()
            asyncTransform(element) { newElement in
                result.value[resultIndex] = newElement
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            let transformed = result.value.map { newElement -> NewElement in
                guard let newElement = newElement else {
                    preconditionFailure("Completion handler of `transform` not called on every invocation")
                }
                return newElement
            }
            completion(transformed)
        }
    }
}
