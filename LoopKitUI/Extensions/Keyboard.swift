//
//  Keyboard.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/18/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import UIKit


public final class Keyboard: ObservableObject {
    public struct State {
        public var height: CGFloat = 0
        public var animationDuration: TimeInterval = 0.25
    }

    @Published var state = State()
    private var keyboardFrameChangeCancellable: AnyCancellable?

    static let shared = Keyboard()

    private init() {
        let notificationNames: [Notification.Name] = [
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardDidChangeFrameNotification,
            UIResponder.keyboardWillHideNotification,
            UIResponder.keyboardDidHideNotification,
        ]
        let hideNames: Set<Notification.Name> = [
            UIResponder.keyboardWillHideNotification,
            UIResponder.keyboardDidHideNotification,
        ]
        keyboardFrameChangeCancellable = Publishers.MergeMany(
            notificationNames.map { NotificationCenter.default.publisher(for: $0) }
        )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self, let userInfo = notification.userInfo else {
                    return
                }

                let height: CGFloat
                if hideNames.contains(notification.name) {
                    height = 0
                } else if let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    height = UIScreen.main.bounds.intersection(keyboardFrame).height
                } else {
                    height = 0
                }

                let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25

                if self.state.height != height {
                    self.state = State(height: height, animationDuration: animationDuration)
                }
            }
    }
}
