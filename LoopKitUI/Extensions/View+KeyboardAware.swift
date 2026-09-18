//
//  View+KeyboardAware.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

extension View {
    public func onKeyboardStateChange(perform updateForKeyboardState: @escaping (_ keyboardHeight: Keyboard.State) -> Void) -> some View {
        onReceive(Keyboard.shared.$state, perform: updateForKeyboardState)
    }

    public func keyboardEntryPage() -> some View {
        modifier(KeyboardEntryPage())
    }

    public func autoFocusOnFirstAppearance(_ shouldFocus: Binding<Bool>, enabled: @autoclosure @escaping () -> Bool = true) -> some View {
        modifier(AutoFocusOnFirstAppearance(shouldFocus: shouldFocus, enabled: enabled))
    }

    public func keyboardDismissAccessory() -> some View {
        background(KeyboardDismissAccessoryInstaller())
    }
}

private struct AutoFocusOnFirstAppearance: ViewModifier {
    @Binding var shouldFocus: Bool
    let enabled: () -> Bool

    @State private var hasAutoFocused = false
    @State private var isVisible = false

    private static var transitionSettleDelay: TimeInterval { 0.5 }

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                guard !hasAutoFocused, enabled() else { return }
                hasAutoFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.transitionSettleDelay) {
                    guard isVisible else { return }
                    shouldFocus = true
                }
            }
            .onDisappear {
                isVisible = false
                shouldFocus = false
            }
    }
}

private struct KeyboardEntryPage: ViewModifier {
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .scrollBounceBehavior(.always)
            .scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(isKeyboardVisible)
            .onKeyboardStateChange { state in
                isKeyboardVisible = state.height > 0
            }
    }
}

private struct KeyboardDismissAccessoryInstaller: UIViewControllerRepresentable {
    @Binding private var observed: Void

    init() {
        _observed = .constant(())
    }

    func makeUIViewController(context: Context) -> InstallerController {
        InstallerController()
    }

    func updateUIViewController(_ controller: InstallerController, context: Context) {
        controller.refreshSoon()
    }

    static func dismantleUIViewController(_ controller: InstallerController, coordinator: ()) {
        controller.stop()
    }

    final class InstallerController: UIViewController {
        
        private weak var textField: UITextField?
        
        private var originalAccessory: UIView?
        private var accessory: UIView?
        private var refreshPending = false
        private var isStopped = false
        private var keyboardFrame: CGRect?

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false

            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(editingBegan), name: UITextField.textDidBeginEditingNotification, object: nil)
            center.addObserver(self, selector: #selector(textChanged), name: UITextField.textDidChangeNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillShowNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardChanged), name: UIResponder.keyboardDidShowNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardChanged), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardHidden), name: UIResponder.keyboardDidHideNotification, object: nil)
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            
            refreshSoon()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            
            refresh()
            refreshSoon()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            refresh()
        }

        func refreshSoon() {
            guard !isStopped, !refreshPending else { return }
            
            refreshPending = true
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refreshPending = false
                self.refresh()
            }
        }

        private func refresh() {
            guard !isStopped, view.window != nil, let field = findTextField() else { return }
            
            if textField !== field {
                restoreAccessory()
                textField = field
                originalAccessory = field.inputAccessoryView
                accessory = KeyboardDismissAccessory.wantsStrip(field) ? KeyboardDismissAccessory.make(dismissing: field) : nil
            }
            
            guard let accessory else { return }
            
            if field.inputAccessoryView !== accessory {
                field.inputAccessoryView = accessory
                
                if field.isFirstResponder, keyboardFrame != nil {
                    field.reloadInputViews()
                }
            }
        }

        private func findTextField() -> UITextField? {
            guard !view.bounds.isEmpty else { return nil }
            
            var ancestor = view.superview
            
            while let container = ancestor {
                let markerFrame = view.convert(view.bounds, to: container)
                var matches: [UITextField] = []
                
                func visit(_ candidate: UIView) {
                    guard !candidate.isHidden, candidate.alpha > 0 else { return }
                    
                    if let field = candidate as? UITextField {
                        let frame = field.convert(field.bounds, to: container)
                        if !frame.isEmpty, markerFrame.insetBy(dx: -1, dy: -1).contains(frame) {
                            matches.append(field)
                        }
                        return
                    }
                    
                    candidate.subviews.forEach(visit)
                }
                
                visit(container)
                
                if !matches.isEmpty {
                    return matches.count == 1 ? matches.first : nil
                }
                
                if container is UICollectionViewCell || container is UITableViewCell {
                    return nil
                }
                
                ancestor = container.superview
            }
            
            return nil
        }

        @objc private func editingBegan(_ notification: Notification) {
            refresh()
            
            guard notification.object as? UITextField === textField else { return }
            
            refreshSoon()
        }

        @objc private func textChanged(_ notification: Notification) {
            guard notification.object as? UITextField === textField else { return }
            
            refreshSoon()
        }

        @objc private func keyboardWillChange(_ notification: Notification) {
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
            let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
            
            keyboardFrame = frame
            
            refresh()
            
            revealField(animatedOver: duration, options: UIView.AnimationOptions(rawValue: curveValue << 16))
        }

        @objc private func keyboardChanged(_ notification: Notification) {
            keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            
            refresh()
            
            DispatchQueue.main.async { [weak self] in
                self?.revealField(animatedOver: 0.15, options: .curveEaseOut)
            }
        }

        @objc private func keyboardHidden(_ notification: Notification) {
            keyboardFrame = nil
        }

        private func revealField(animatedOver duration: TimeInterval, options: UIView.AnimationOptions) {
            guard !isStopped, let field = textField, field.isFirstResponder, let window = field.window, let keyboardFrame = keyboardFrame else {
                return
            }
            
            let keyboard = window.convert(keyboardFrame, from: window.screen.coordinateSpace)
            
            guard keyboard.intersects(window.bounds) else {
                return
            }

            var row: UIView = field
            var ancestor = field.superview
            
            while let container = ancestor {
                if let scrollView = container as? UIScrollView {
                    guard !scrollView.isDragging, !scrollView.isDecelerating else {
                        return
                    }
                    
                    scrollView.layoutIfNeeded()
                    
                    let rowFrame = row.convert(row.bounds, to: scrollView)
                    let keyboardTop = scrollView.convert(keyboard, from: window).minY
                    let visibleBottom = min(scrollView.bounds.maxY - scrollView.adjustedContentInset.bottom, keyboardTop)
                    let clearance: CGFloat = 12
                    let distance = rowFrame.maxY + clearance - visibleBottom
                    
                    guard distance > 0 else {
                        return
                    }
                    
                    let keyboardOverlap = max(
                        0,
                        scrollView.bounds.maxY - keyboardTop
                    )
                    
                    let bottomInset = max(
                        scrollView.adjustedContentInset.bottom,
                        keyboardOverlap
                    )
                    
                    let maximumOffset = max(
                        -scrollView.adjustedContentInset.top,
                         scrollView.contentSize.height - scrollView.bounds.height + bottomInset
                    )
                    
                    let offset = min(
                        scrollView.contentOffset.y + distance,
                        maximumOffset
                    )
                    
                    if offset > scrollView.contentOffset.y + 0.5 {
                        UIView.animate(
                            withDuration: duration,
                            delay: 0,
                            options: options.union([.beginFromCurrentState, .allowUserInteraction])
                        ) {
                            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: offset), animated: false)
                        }
                    }
                    
                    return
                }
                
                if container is UICollectionViewCell || container is UITableViewCell {
                    row = container
                }
                
                ancestor = container.superview
            }
        }

        private func restoreAccessory() {
            if let field = textField, let accessory = accessory, field.inputAccessoryView === accessory {
                field.inputAccessoryView = originalAccessory
                
                if field.isFirstResponder {
                    field.reloadInputViews()
                }
            }
            
            textField = nil
            originalAccessory = nil
            accessory = nil
        }

        func stop() {
            isStopped = true
            
            NotificationCenter.default.removeObserver(self)
            
            restoreAccessory()
        }
    }
}

@available(iOSApplicationExtension, unavailable)
public enum KeyboardDismissal {
    public static func resignFirstResponder() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
