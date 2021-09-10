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
    let major: Int
    let minor: Int
    let patch: Int
    init?(_ value: String) {
        guard value.matches(SemanticVersion.versionRegex) else { return nil }
        let split = value.split(separator: ".")
        guard split.count == 3 else { return nil }
        guard let major = Int(split[0]),
              let minor = Int(split[1]),
              let patch = Int(split[2]) else {
            return nil
        }
        assert(major >= 0)
        assert(minor >= 0)
        assert(patch >= 0)
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major == rhs.major {
            if lhs.minor == rhs.minor {
                if lhs.patch == rhs.patch {
                    return false
                } else {
                    return lhs.patch < rhs.patch
                }
            } else {
                return lhs.minor < rhs.minor
            }
        } else {
            return lhs.major < rhs.major
        }
    }
}

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
