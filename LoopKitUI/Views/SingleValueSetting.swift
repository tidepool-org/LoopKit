//
//  SingleValueSetting.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct SingleValueSetting<ValueContent: View, ValuePicker: View>: View {
    var valueContent: (_ isEditing: Bool) -> ValueContent
    var valuePicker: ValuePicker

    @State var isEditing = false

    public init(
        @ViewBuilder valueContent: @escaping (_ isEditing: Bool) -> ValueContent,
        @ViewBuilder valuePicker: () -> ValuePicker
    ) {
        self.valueContent = valueContent
        self.valuePicker = valuePicker()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                valueContent(isEditing)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    self.isEditing.toggle()
                }
            }

            if isEditing {
                valuePicker
                    .padding(.horizontal, -8)
                    .transition(.fadeInFromTop)
            }
        }

    }
}
