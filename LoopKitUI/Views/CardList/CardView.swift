//
//  CardView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// A platter displaying a number of components over a rounded background tile.
public struct CardView: View {
    private var parts: [AnyView]

    init(components: [Card.Component]) {
        self.parts = components.compactMap { component in
            switch component {
            case .static(let view):
                return view
            case .dynamic(let identifiedViews):
                guard let lastId = identifiedViews.last?.id else {
                    return nil
                }

                return AnyView(
                    ForEach(identifiedViews, id: \.id) { view, id in
                        VStack {
                            view
                            if id != lastId {
                                CardSectionDivider()
                            }
                        }
                    }
                )
            }
        }
    }

    public var body: some View {
        VStack {
            ForEach(parts.indices, id: \.self) { index in
                VStack {
                    self.parts[index]

                    if index != self.parts.indices.last! {
                        CardSectionDivider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(CardBackground())
        .padding(.horizontal)
    }
}

private struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .foregroundColor(Color(.systemBackground))
    }
}

private struct CardSectionDivider: View {
    var body: some View {
        Divider()
            .padding(.trailing, -16)
    }
}


struct Card_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            CardView(components: [Text("One"), Text("Two"), Text("Three")].map { Card.Component.static(AnyView($0)) })
                .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
    }
}
