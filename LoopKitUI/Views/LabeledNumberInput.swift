//
//  LabeledNumberInput.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct LabeledNumberInput: View {
    @Binding var value: Double?
    let font: Font
    let label: String
    let placeholder: String
    let allowFractions: Bool
    @Binding var isFocused: Bool
    @FocusState private var textFieldFocused: Bool
    @State private var enteredValue: String
    
    private var numberFormatter: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = allowFractions ? .decimal : .none
        return numberFormatter
    }
    
    public init(value: Binding<Double?>, font: Font = .largeTitle, label: String, placeholder: String? = nil, allowFractions: Bool = false, isFocused: Binding<Bool> = .constant(false)) {
        _value = value
        self.font = font
        self.label = label
        self.placeholder = placeholder ?? LocalizedString("Value", comment: "Placeholder text until value is entered")
        self.allowFractions = allowFractions
        self._isFocused = isFocused
        let formatter = NumberFormatter()
        formatter.numberStyle = allowFractions ? .decimal : .none
        self._enteredValue = State(initialValue: value.wrappedValue.flatMap { formatter.string(from: NSNumber(value: $0)) } ?? "")
    }
        
    public var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 5) {
                TextField(placeholder, text: $enteredValue)
                    .textFieldStyle(.plain)
                    .font(font)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(allowFractions ? .decimalPad : .numberPad)
                    .focused($textFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { textFieldFocused = false }
                    .accessibilityIdentifier("dismissibleKeyboardTextField")
                    .accessibility(label: Text(String(format: LocalizedString("Enter %1$@ value", comment: "Format string for accessibility label for value entry. (1: value label)"), label)))
                Text(self.label)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 7)
                    .frame(width: geometry.size.width/2, alignment: .leading)
            }
        }
        .onChange(of: enteredValue) { _, text in
            value = numberFormatter.number(from: text)?.doubleValue
        }
        .onChange(of: value) { _, newValue in
            if !textFieldFocused {
                enteredValue = newValue.flatMap { numberFormatter.string(from: NSNumber(value: $0)) } ?? ""
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

struct LabeledNumberInput_Previews: PreviewProvider {
    static var previews: some View {
        LabeledNumberInput(
            value: .constant(nil),
            label: "mg/dL",
            allowFractions: true)
    }
}
