//
//  CardListBuilder.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// Constructs an array of `CardView` views from arbitrary `View` instances.
///
/// A multi-component card can be constructed using one of `Card`'s initializers.
@_functionBuilder
public struct CardListBuilder {
    /// A list of `CardView` instances, where `nil` represents a location in the list where a `CardView` could be inserted under a different state.
    public typealias Component = [CardView?]

    public static func buildExpression<V: View>(_ view: V) -> Component {
        [CardView(components: [.static(AnyView(view))])]
    }

    public static func buildExpression(_ card: Card) -> Component {
        [CardView(components: card.components)]
    }

    public static func buildIf(_ component: Component?) -> Component {
        // If `nil` (i.e. a condition is `false`), leave a placeholder `nil` view to enable smooth insertion when the condition becomes `true`.
        component ?? [nil]
    }

    public static func buildBlock(_ components: Component...) -> Component {
        components.flatMap { $0 }
    }
}
