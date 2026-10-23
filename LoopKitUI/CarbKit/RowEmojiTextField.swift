//
//  RowEmojiTextField.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 8/1/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// Has the same functions as `RowTextField` and uses an `EmojiInputController` as the keyboard. This struct handles `standardInputMode` as well.
struct RowEmojiTextField: View {
    @Binding private var text: String
    @Binding private var isFocused: Bool
    
    private var placeholder: String
    
    @StateObject private var viewModel: EmojiTextFieldViewModel
    
    class EmojiTextFieldViewModel: ObservableObject, EmojiInputControllerDelegate {
        @Published var standardInputMode = false
        let didSelectItemInSection: ((Int) -> Void)?
        private let emojiType: EmojiDataSourceType

        @MainActor lazy var emojiInputController: EmojiInputController = {
            let controller = EmojiInputController.instance(withEmojis: emojiType.dataSource())
            controller.delegate = self
            return controller
        }()
        
        init(emojiType: EmojiDataSourceType, didSelectItemInSection: ((Int) -> Void)?) {
            self.emojiType = emojiType
            self.didSelectItemInSection = didSelectItemInSection
        }
        
        func emojiInputControllerDidAdvanceToStandardInputMode(_ controller: EmojiInputController) {
            self.standardInputMode = true
        }
        
        func emojiInputControllerDidSelectItemInSection(_ section: Int) {
            didSelectItemInSection?(section)
        }
    }
    
    init(text: Binding<String>, isFocused: Binding<Bool>, placeholder: String = "", emojiType: EmojiDataSourceType, didSelectItemInSection: ((Int) -> Void)? = nil) {
        self._text = text
        self._isFocused = isFocused
        self.placeholder = placeholder
        self._viewModel = StateObject(wrappedValue: EmojiTextFieldViewModel(emojiType: emojiType, didSelectItemInSection: didSelectItemInSection))
    }
    
    var body: some View {
        if viewModel.standardInputMode {
            RowTextField(text: $text, isFocused: $isFocused, maxLength: 20, configuration: { textField in
                textField.textAlignment = .right
                textField.font = UIFont.preferredFont(forTextStyle: .title3)
                textField.autocorrectionType = .no
                textField.autocapitalizationType = .none
                if textField.customInput != nil {
                    textField.customInput = nil
                    if textField.isFirstResponder {
                        textField.reloadInputViews()
                    }
                }
                textField.placeholder = placeholder
            }).accessibilityIdentifier("textField_FoodType")
        }
        else {
            RowTextField(text: $text, isFocused: $isFocused, maxLength: 20, configuration: { textField in
                textField.textAlignment = .right
                textField.font = UIFont.preferredFont(forTextStyle: .title3)
                // Do not register a custom keyboard merely because its containing form appeared.
                if isFocused {
                    let controller = viewModel.emojiInputController
                    if textField.customInput !== controller {
                        textField.customInput = controller
                        if textField.isFirstResponder {
                            textField.reloadInputViews()
                        }
                    }
                }
                textField.placeholder = placeholder
            }).accessibilityIdentifier("textField_FoodType")
        }
    }
}
