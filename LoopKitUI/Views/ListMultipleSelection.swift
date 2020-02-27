//
//  ListMultipleSelection.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct ListMultipleSelection<Item>: View where Item: Hashable, Item: CustomStringConvertible {
    var items: [Item]
    @Binding var selectedItems: Set<Item>
    
    public init(items: [Item], selectedItems: Binding<Set<Item>>) {
        self.items = items
        _selectedItems = selectedItems
    }
    
    public var body: some View {
        List(items, id:\.self) { item in
            MultipleSelectionRow<Item>(item: item, selectedItems: self.$selectedItems)
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
    }
}

struct MultipleSelectionRow<Item>: View where Item: CustomStringConvertible, Item: Hashable {
    var item: Item
    
    @Binding var selectedItems: Set<Item>
    
    var isSelected: Bool {
        selectedItems.contains(item)
    }
    
    var body: some View {
        HStack {
            Button(action: {
                if self.isSelected {
                    self.selectedItems.remove(self.item)
                } else {
                    self.selectedItems.insert(self.item)
                }
            }) {
                Text(String(describing: item))
                    .foregroundColor(.primary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
    }
}

struct SelectableList_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        static var fruit = ["Orange", "Apple", "Banana", "Peach", "Grape"]
        @State(initialValue: [fruit[1], fruit[3]]) var selectedFruit: Set<String>
        
        var body: some View {
            ListMultipleSelection<String>(items: SelectableList_Previews.PreviewWrapper.fruit, selectedItems: $selectedFruit)
        }
    }
}
