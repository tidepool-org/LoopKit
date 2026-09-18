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
    @Binding var isFocused: Bool
    @FocusState private var textFieldFocused: Bool
    
    public init(label: String, placeholder: String = "", value: Binding<String>, isFocused: Binding<Bool> = .constant(false)) {
        self.label = label
        self.placeholder = placeholder
        _value = value
        _isFocused = isFocused
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
                    .submitLabel(.done)
                    .focused($textFieldFocused)
                    .onSubmit { textFieldFocused = false }
                    .frame(maxWidth: geometry.size.width/2, alignment: .trailing)
            }
        }
        .onChange(of: isFocused, initial: true) { _, focused in
            textFieldFocused = focused
        }
        .onChange(of: textFieldFocused) { _, focused in
            isFocused = focused
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
        var body: some View {
            LabeledTextField(label: "Name", placeholder: "Schedule Name", value: $value)
        }
    }
}
