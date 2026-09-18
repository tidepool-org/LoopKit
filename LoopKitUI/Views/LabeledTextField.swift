//
//  LabeledTextField.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct LabeledTextField: View {
    var label: String
    var placeholder: String
    @Binding var value: String
    let focus: FocusState<Bool>.Binding
    
    public init(label: String, placeholder: String = "", value: Binding<String>, focus: FocusState<Bool>.Binding) {
        self.label = label
        self.placeholder = placeholder
        _value = value
        self.focus = focus
    }
    
    public var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(self.label)
                    .foregroundColor(.primary)
                    .frame(maxWidth: geometry.size.width/2, alignment: .leading)
                Spacer()
                TextField(self.placeholder, text: self.$value)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.alphabet)
                    .inputField(focus: focus)
                    .frame(maxWidth: geometry.size.width/2, alignment: .trailing)
            }
        }
    }
}

struct LabelTextField_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            PreviewWrapper()
        }
    }
        
    struct PreviewWrapper: View {
        @State(initialValue: "Overnight") var value: String
        @FocusState private var isFocused: Bool
        var body: some View {
            LabeledTextField(label: "Name", placeholder: "Schedule Name", value: $value, focus: $isFocused)
        }
    }
}
