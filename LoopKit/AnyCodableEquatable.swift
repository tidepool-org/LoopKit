//
//  AnyCodableEquatable.swift
//  LoopKit
//
//  Created by Darin Krauss on 2/8/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public struct AnyCodableEquatable: Codable, Equatable {
    public enum Error: Swift.Error {
        case unknownType
    }

    public let any: Any
    private let equals: (Self) -> Bool

    public init<T: Codable & Equatable>(_ any: T) {
        self.any = any
        self.equals = { $0.any as? T == any }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        if let value = try? container.decode(String.self) {
            self.init(value)
        } else if let value = try? container.decode(Int.self) {
            self.init(value)
        } else if let value = try? container.decode(Double.self) {
            self.init(value)
        } else if let value = try? container.decode(Bool.self) {
            self.init(value)
        } else {
            throw Error.unknownType
        }
    }

    public func encode(to encoder: Encoder) throws {
        try (any as? Encodable)?.encode(to: encoder)
    }

    public static func ==(lhs: AnyCodableEquatable, rhs: AnyCodableEquatable) -> Bool {
        return lhs.equals(rhs)
    }
}
