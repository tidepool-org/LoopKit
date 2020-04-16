//
//  Card.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// A data structure used to compose a `CardView`.
///
/// In a `CardListBuilder`, a single-component `Card` is implicitly created from any expression conforming to `View`.
/// A multi-component `Card` can be constructed using one of `Card`'s initializers.
///
/// A multi-component card may consist of purely static components:
/// ```
/// Card {
///     Text("Top")
///     Text("Middle")
///     Text("Bottom")
/// }
/// ```
///
/// Cards of a dynamic number of components can be constructed from identifiable data:
/// ```
/// Card(of: 1...5, id: \.self) { value in
///     Text("\(value)")
/// }
/// ```
///
/// Finally, dynamic components can be unrolled to intermix with static components via `Splat`:
/// ```
/// Card {
///     Text("Above dynamic data")
///     Splat(1...5, id: \.self) { value in
///         Text("Dynamic data \(value)")
///     }
///     Text("Below dynamic data")
/// }
/// ```
public struct Card {
    public enum Component {
        case `static`(AnyView)
        case dynamic([(view: AnyView, id: AnyHashable)])
    }

    public var components: [Component]

    public init(@CardBuilder components: () -> [Component]) {
        self.components = components()
    }

    public init<Data: RandomAccessCollection, ID: Hashable, Content: View>(
        of data: Data,
        id: KeyPath<Data.Element, ID>,
        rowContent: (Data.Element) -> Content
    ) {
        components = [.dynamic(Splat(data, id: id, rowContent: rowContent).identifiedViews)]
    }

    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        @ViewBuilder rowContent:  (Data.Element) -> Content
    ) where Data.Element: Identifiable {
        self.init(of: data, id: \.id, rowContent: rowContent)
    }
}
