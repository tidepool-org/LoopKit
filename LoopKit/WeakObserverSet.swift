//
//  WeakObserverSet.swift
//  LoopKit
//
//  Created by Michael Pangburn
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


/// A set-like collection of weak types, providing closure-baesd iteration on a client-specified queue
/// Mutations and iterations are thread-safe
public class WeakObserverSet<Observer> {
    private typealias Identifier = ObjectIdentifier
    private typealias Element = ObserverDispatchContainer<Observer>

    private class ObserverDispatchContainer<Observer> {
        private weak var _observer: AnyObject?
        weak var queue: DispatchQueue?

        var observer: Observer? {
            return _observer as? Observer
        }

        init(observer: Observer, queue: DispatchQueue) {
            // All Swift values are implicitly convertible to `AnyObject`,
            // so this runtime check is the tradeoff for supporting class-constrained protocol types.
            precondition(Mirror(reflecting: observer).displayStyle == .class, "Weak references can only be held of class types.")

            self._observer = observer as AnyObject
            self.queue = queue
        }

        func call(_ body: @escaping (_ observer: Observer) -> Void) {
            guard let queue = self.queue, let observer = self.observer else {
                return
            }

            queue.async {
                body(observer)
            }
        }
    }

    private let observers: Locked<[Identifier: Element]>

    public init() {
        observers = Locked([:])
    }

    /// Adds an observer and its calling queue
    ///
    /// - Parameters:
    ///   - observer: The observer
    ///   - queue: The queue to use when calling the observer
    public func addObserver(_ observer: Observer, queue: DispatchQueue) {
        insert(ObserverDispatchContainer(observer: observer, queue: queue))
    }

    /// Prunes any observer references that have been deallocated
    /// - Returns: A reference to the instance for easy chaining
    public func cleanupDeallocatedElements() -> Self {
        observers.mutate { (storage) in
            for (id, element) in storage where element.observer == nil {
                storage.removeValue(forKey: id)
            }
        }
        return self
    }

    /// Whether the observer is in the set
    ///
    /// - Parameter observer: The observer
    /// - Returns: True if the observer is in the set
    public func contains(_ observer: Observer) -> Bool {
        let id = identifier(for: observer)
        return observers.value[id] != nil
    }

    /// The total number of observers in the set
    ///
    /// Deallocated references are counted, so calling `cleanupDeallocatedElements` is advised to maintain accuracy of this value
    public var count: Int {
        return observers.value.count
    }

    /// Calls the given closure on each observer in the set, on the queue specified when the observer was added
    ///
    /// The order of calls is not defined
    ///
    /// - Parameter body: The closure to execute
    public func forEach(_ body: @escaping (Observer) -> Void) {
        // Hold the lock while we iterate, since each call is dispatched out
        observers.mutate { (observers) in
            observers.forEach { (pair) in
                pair.value.call(body)
            }
        }
    }

    /// Removes the specified observer from the set
    ///
    /// - Parameter observer: The observer
    public func removeObserver(_ observer: Observer) {
        removeValue(forKey: identifier(for: observer))
    }
}

extension WeakObserverSet {
    private func identifier(for observer: Observer) -> ObjectIdentifier {
        return ObjectIdentifier(observer as AnyObject)
    }

    private func identifier(for element: Element) -> ObjectIdentifier? {
        guard let observer = element.observer else {
            return nil
        }
        return identifier(for: observer)
    }

    @discardableResult
    private func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element?) {
        guard let id = identifier(for: newMember) else {
            return (inserted: false, memberAfterInsert: nil)
        }
        var result: (inserted: Bool, memberAfterInsert: Element?)!
        observers.mutate { (storage) in
            if let existingMember = storage[id] {
                result = (inserted: false, memberAfterInsert: existingMember)
            } else {
                storage[id] = newMember
                result = (inserted: true, memberAfterInsert: newMember)
            }
        }
        return result
    }

    @discardableResult
    private func removeValue(forKey key: Identifier) -> Element? {
        var previousMember: Element?
        observers.mutate { (storage) in
            previousMember = storage.removeValue(forKey: key)
        }
        return previousMember
    }
}
