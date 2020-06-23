//
//  ActionButton.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2020-03-04.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

// TODO: Migrate use sites to ActionButtonStyle
public struct ActionButton: ViewModifier {
    private let fontColor: Color
    private let backgroundColor: Color
    private let edgeColor: Color
    private let cornerRadius: CGFloat = 10
    
    public enum ButtonType {
        case primary
        case secondary
        case destructive
        case tidepoolPrimary
        case tidepoolSecondary
    }
    
    init(_ style: ButtonType = .primary) {
        switch style {
        case .primary:
            fontColor = .white
            backgroundColor = .accentColor
            edgeColor = .clear
        case .destructive:
            fontColor = .white
            backgroundColor = .destructive
            edgeColor = .clear
        case .secondary:
            fontColor = .accentColor
            backgroundColor = .clear
            edgeColor = .accentColor
        case .tidepoolPrimary:
            fontColor = .white
            backgroundColor = Color(#colorLiteral(red: 0.3647058824, green: 0.4745098039, blue: 1, alpha: 1))
            edgeColor = Color(#colorLiteral(red: 0.3647058824, green: 0.4745098039, blue: 1, alpha: 1))
        case .tidepoolSecondary:
            fontColor = Color(#colorLiteral(red: 0.3647058824, green: 0.4745098039, blue: 1, alpha: 1))
            backgroundColor = Color(#colorLiteral(red: 0.9490196078, green: 0.9450980392, blue: 0.9647058824, alpha: 1))
            edgeColor = Color(#colorLiteral(red: 0.3647058824, green: 0.4745098039, blue: 1, alpha: 1))
        }
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(.all)
            .foregroundColor(fontColor)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(edgeColor))
    }
}

public extension View {
    func actionButtonStyle(_ style: ActionButton.ButtonType = .primary) -> some View {
        ModifiedContent(content: self, modifier: ActionButton(style))
    }
}
