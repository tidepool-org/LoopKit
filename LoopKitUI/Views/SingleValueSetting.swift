//
//  SingleValueSetting.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct SingleValueSetting<ValueContent: View, ValuePicker: View>: View {
    @Binding var isEditing: Bool
    var valueContent: ValueContent
    var valuePicker: ValuePicker

    public init(
        isEditing: Binding<Bool>,
        @ViewBuilder valueContent: () -> ValueContent,
        @ViewBuilder valuePicker: () -> ValuePicker
    ) {
        self._isEditing = isEditing
        self.valueContent = valueContent()
        self.valuePicker = valuePicker()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                valueContent
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
