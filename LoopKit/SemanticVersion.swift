//
//  SemanticVersion.swift
//  LoopKit
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

struct SemanticVersion: Comparable {
    static let versionRegex = "[0-9]+.[0-9]+.[0-9]+"
    let value: String
    init?(_ value: String) {
        guard value.matches(SemanticVersion.versionRegex) else { return nil }
        self.value = value
    }
    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let lhsParts = lhs.value.split(separator: ".")
        let rhsParts = rhs.value.split(separator: ".")
        switch lhsParts[0].compare(rhsParts[0], options: String.CompareOptions.numeric) {
        case .orderedAscending:
            return true
        case .orderedSame:
            switch lhsParts[1].compare(rhsParts[1], options: String.CompareOptions.numeric) {
            case .orderedAscending:
                return true
            case .orderedSame:
                switch lhsParts[2].compare(rhsParts[2], options: String.CompareOptions.numeric) {
                case .orderedAscending:
                    return true
                case .orderedSame:
                    return false
                case .orderedDescending:
                    return false
                }
            case .orderedDescending:
                return false
            }
        case .orderedDescending:
            return false
        }
    }
}

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
