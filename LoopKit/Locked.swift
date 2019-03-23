//
//  Locked.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import os.lock


public class Locked<T> {
    private var _lock: UnsafeMutablePointer<os_unfair_lock>
    private var _value: T

    public init(_ value: T) {
        _lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock())
        _value = value
    }

    deinit {
        _lock.deallocate()
    }

    public var value: T {
        get {
            os_unfair_lock_lock(_lock)
            defer { os_unfair_lock_unlock(_lock) }
            return _value
        }
        set {
            os_unfair_lock_lock(_lock)
            defer { os_unfair_lock_unlock(_lock) }
            _value = newValue
        }
    }

    @discardableResult public func mutate(_ changes: (_ value: inout T) -> Void) -> T {
        os_unfair_lock_lock(_lock)
        defer { os_unfair_lock_unlock(_lock) }
        changes(&_value)
        return _value
    }
}
