//
//  CardList.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// Displays a list of cards similar to a `List` with an inset grouped style,
/// but without the baggage of `UITableViewCell` resizing, enabling cells to expand smoothly.
struct CardList: View {
    var title: Text
    var cards: [CardView?]
    var spacing: CGFloat

    init(title: Text, spacing: CGFloat = 8, @CardListBuilder content: () -> [CardView?]) {
        self.init(title: title, spacing: spacing, content: content())
    }

    init(title: Text, spacing: CGFloat = 8, content: [CardView?]) {
        self.title = title
        self.spacing = spacing
        self.cards = content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                titleText

                VStack(spacing: self.spacing) {
                    ForEach(self.cards.indices, id: \.self) { index in
                        self.cards[index]
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var titleText: some View {
        HStack {
            title
                .font(.largeTitle)
                .bold()
            Spacer()
        }
        .padding()
        .padding(.bottom, 4)
        .background(Color(.systemGroupedBackground))
    }
}

struct CardList_Previews: PreviewProvider {
    static var previews: some View {
        CardList(title: Text("Example")) {
            Text("Simple card")
            Text("A card that's going to require a little bit more space because it'll go onto multiple lines if I type for long enough")

            Card {
                Text("Top piece")
                Splat(1...4, id: \.self) { integer in
                    Text("Dynamic piece \(integer)")
                }
                Text("Bottom piece")
            }
        }
    }
}
