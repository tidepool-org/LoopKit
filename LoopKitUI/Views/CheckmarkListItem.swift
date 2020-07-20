//
//  CheckmarkListItem.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct CheckmarkListItem: View {
    
    var title: Text
    var description: Text
    @Binding var isSelected: Bool

    public init(title: Text, description: Text, isSelected: Binding<Bool>) {
        self.title = title
        self.description = description
        self._isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.headline)
                description
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 12)

            selectionIndicator
                .frame(width: 26, height: 26)
        }
        .animation(nil)
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .background(Circle().stroke()) // Ensure size aligns with open circle
                .foregroundColor(.accentColor)
        } else {
            Button(action: { self.isSelected = true }) {
                Circle()
                    .stroke()
                    .foregroundColor(Color(.systemGray4))
            }
        }
    }
}

public struct DurationBasedCheckmarkListItem: View {
   
    var title: Text
    var description: Text
    @Binding var isSelected: Bool
    @Binding var duration: TimeInterval
    var validDurationRange: ClosedRange<TimeInterval>

    public init(title: Text, description: Text, isSelected: Binding<Bool>, duration: Binding<TimeInterval>, validDurationRange: ClosedRange<TimeInterval>) {
        self.title = title
        self.description = description
        self._isSelected = isSelected
        self._duration = duration
        self.validDurationRange = validDurationRange
    }

    public var body: some View {
        VStack(spacing: 0) {
            CheckmarkListItem(title: title, description: description, isSelected: $isSelected)

            if isSelected {
                DurationPicker(duration: $duration, validDurationRange: validDurationRange)
                    .frame(height: 216)
                    .transition(.fadeInFromTop)
            }
        }
    }
}
