//
//  CarbQuantityRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopAlgorithm

public struct CarbQuantityRow<Field: Hashable>: View {
    @Binding private var quantity: Double?
    private let focus: FocusState<Field?>.Binding
    private let field: Field
    
    private let title: String
    private let preferredCarbUnit: LoopUnit
    private let nextField: Field?
    private var nextAction: (() -> Void)?
    
    @State private var carbInput: String = ""
    
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    public init(quantity: Binding<Double?>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, preferredCarbUnit: LoopUnit = .gram, next: Field? = nil) {
        self._quantity = quantity
        self.focus = focus
        self.field = field
        self.title = title
        self.preferredCarbUnit = preferredCarbUnit
        self.nextField = next
    }

    public init(quantity: Binding<Double?>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, preferredCarbUnit: LoopUnit = .gram, next: @escaping () -> Void) {
        self.init(quantity: quantity, focus: focus, equals: field, title: title, preferredCarbUnit: preferredCarbUnit)
        self.nextAction = next
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            textField
            .multilineTextAlignment(.trailing)
            .font(.body)
            .onTapGesture {
                // so that row does not lose focus on cursor move
                if focus.wrappedValue != field {
                    rowTapped()
                }
            }
            .accessibilityIdentifier("textField_CarbsAmount")
            
            carbUnitsLabel
        }
        .accessibilityElement(children: .combine)
        .onChange(of: carbInput) { newValue in
            updateQuantity(with: newValue)
        }
        .onChange(of: quantity) { newQuantity in
            updateCarbInput(with: newQuantity)
        }
        .onAppear {
            updateCarbInput(with: quantity)
        }
        .onTapGesture {
            rowTapped()
        }
    }

    @ViewBuilder
    private var textField: some View {
        if let nextAction {
            KeyboardTextField("0", text: $carbInput, focus: focus, equals: field, keyboardType: .decimalPad, maxLength: 5, next: nextAction)
        } else {
            KeyboardTextField("0", text: $carbInput, focus: focus, equals: field, keyboardType: .decimalPad, maxLength: 5, next: nextField)
        }
    }
    
    private var carbUnitsLabel: some View {
        Text(QuantityFormatter(for: preferredCarbUnit).localizedUnitStringWithPlurality())
            .foregroundColor(Color(.secondaryLabel))
    }
    
    // Update quantity based on text field input
    private func updateQuantity(with input: String) {
        let filtered = input.filter { "0123456789.".contains($0) }
        if filtered != input {
            self.carbInput = filtered
        }
        
        if let doubleValue = Double(filtered) {
            quantity = doubleValue
        } else {
            quantity = nil
        }
    }
    
    // Update text field input based on quantity
    private func updateCarbInput(with newQuantity: Double?) {
        if let value = newQuantity {
            carbInput = formatter.string(from: NSNumber(value: value)) ?? ""
        } else {
            carbInput = ""
        }
    }
    
    private func rowTapped() {
        withAnimation {
            focus.wrappedValue = focus.wrappedValue == field ? nil : field
        }
    }
}
