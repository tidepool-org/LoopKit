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
    private let nextAction: (() -> Void)?
    
    @State private var carbInput: String = ""
    
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    public init(quantity: Binding<Double?>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, preferredCarbUnit: LoopUnit = .gram, next: Field? = nil) {
        self.init(quantity: quantity, focus: focus, equals: field, title: title, preferredCarbUnit: preferredCarbUnit, nextAction: focus.action(focusing: next))
    }

    public init(quantity: Binding<Double?>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, preferredCarbUnit: LoopUnit = .gram, next: @escaping () -> Void) {
        self.init(quantity: quantity, focus: focus, equals: field, title: title, preferredCarbUnit: preferredCarbUnit, nextAction: next)
    }

    private init(quantity: Binding<Double?>, focus: FocusState<Field?>.Binding, equals field: Field, title: String, preferredCarbUnit: LoopUnit, nextAction: (() -> Void)?) {
        self._quantity = quantity
        self.focus = focus
        self.field = field
        self.title = title
        self.preferredCarbUnit = preferredCarbUnit
        self.nextAction = nextAction
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            KeyboardTextField(
                "0",
                text: $carbInput,
                focus: focus,
                equals: field,
                keyboardType: .decimalPad,
                maxLength: 5,
                nextAction: nextAction
            )
            .multilineTextAlignment(.trailing)
            .font(.body)
            .accessibilityIdentifier("textField_CarbsAmount")
            
            carbUnitsLabel
        }
        .accessibilityElement(children: .combine)
        .onChange(of: carbInput) { _, newValue in
            updateQuantity(with: newValue)
        }
        .onChange(of: quantity) { _, newQuantity in
            updateCarbInput(with: newQuantity)
        }
        .onAppear {
            updateCarbInput(with: quantity)
        }
        .onTapGesture {
            rowTapped()
        }
    }
    
    private var carbUnitsLabel: some View {
        Text(QuantityFormatter(for: preferredCarbUnit).localizedUnitStringWithPlurality())
            .foregroundColor(Color(.secondaryLabel))
    }
    
    // Update quantity based on text field input
    private func updateQuantity(with input: String) {
        // The decimal pad and the formatter both use the locale's separator, such as "," in German.
        let decimalSeparator = formatter.decimalSeparator ?? "."
        let filtered = input.filter { ("0123456789." + decimalSeparator).contains($0) }
        if filtered != input {
            self.carbInput = filtered
        }
        
        if let doubleValue = Double(filtered.replacingOccurrences(of: decimalSeparator, with: ".")) {
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
