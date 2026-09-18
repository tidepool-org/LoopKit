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
    @FocusState private var isFocused: Bool
    
    public init(label: String, placeholder: String = "", value: Binding<String>) {
        self.label = label
        self.placeholder = placeholder
        _value = value
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
                    .focused($isFocused)
                    .onSubmit { isFocused = false }
                    .frame(maxWidth: geometry.size.width/2, alignment: .trailing)
            }
        }
        .keyboardToolbar(isFocused: isFocused, dismiss: { isFocused = false })
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
