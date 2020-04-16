//
//  CardBuilder.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// A function builder designed to construct a `Card`.
///
/// Transformations are applied as follows:
/// - An expression conforming to `View` becomes one component of one card.
/// - An instance of `Splat` is unrolled into a dynamic number of components within one card.
///
/// Any number of components (individual or splatted) can be sequenced and combined into a single card.
@_functionBuilder
public struct CardBuilder {
    public typealias Component = [Card.Component]

    public static func buildExpression<V: View>(_ view: V) -> Component {
        [.static(AnyView(view))]
    }

    public static func buildExpression(_ splat: Splat) -> Component {
        [.dynamic(splat.identifiedViews)]
    }

    public static func buildIf(_ component: Component?) -> Component {
        component ?? []
    }

    public static func buildBlock(_ components: Component...) -> Component {
        components.flatMap { $0 }
    }
}
