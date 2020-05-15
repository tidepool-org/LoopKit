//
//  SingleValueSettingEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct SingleValueSettingEditor<Value: Equatable, ValueContent: View, ValuePicker: View, ActionAreaContent: View>: View {
    var title: Text
    var description: Text
    var value: Value
    var initialValue: Value?
    var valueContent: (_ isEditing: Bool) -> ValueContent
    var valuePicker: ValuePicker
    var actionAreaContent: ActionAreaContent
    var save: () -> Void

    @State var isEditing = false

    public init(
        title: Text,
        description: Text,
        value: Value,
        initialValue: Value?,
        @ViewBuilder valueContent: @escaping (_ isEditing: Bool) -> ValueContent,
        @ViewBuilder valuePicker: () -> ValuePicker,
        @ViewBuilder actionAreaContent: () -> ActionAreaContent,
        onSave save: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.value = value
        self.initialValue = initialValue
        self.valueContent = valueContent
        self.valuePicker = valuePicker()
        self.actionAreaContent = actionAreaContent()
        self.save = save
    }

    public var body: some View {
        ConfigurationPage(
            title: title,
            isSaveButtonEnabled: isSaveButtonEnabled,
            cards: {
                // TODO: Remove conditional when Swift 5.3 ships
                // https://bugs.swift.org/browse/SR-11628
                if true {
                    Card {
                        SettingDescription(text: description)
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
            },
            actionAreaContent: {
                actionAreaContent
                    .padding(.horizontal)
                    .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
            },
            onSave: save
        )
    }

    private var isSaveButtonEnabled: Bool {
        initialValue == nil || value != initialValue!
    }
}
