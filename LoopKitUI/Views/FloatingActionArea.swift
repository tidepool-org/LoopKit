//
//  FloatingActionArea.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// The floating bar pinned below a page's scrolling content that hosts its
/// primary calls to action.
///
/// Layout contract: the bar's content lays out entirely inside the safe area;
/// only the background extends through the bottom safe area (home indicator).
/// Pages using `FloatingActionArea` must NOT apply `.edgesIgnoringSafeArea(.bottom)`
/// for the bar's benefit.
public struct FloatingActionArea<Content: View>: View {
    private let content: Content

    @State private var bottomSafeAreaInset: CGFloat = 0

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if Content.self != EmptyView.self {
            VStack(spacing: 12) {
                content
            }
            .padding([.horizontal, .top])
            .padding(.bottom, bottomSafeAreaInset > 0 ? 12 : 16)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { bottomSafeAreaInset = geometry.safeAreaInsets.bottom }
                        .onChange(of: geometry.safeAreaInsets.bottom) { _, inset in
                            bottomSafeAreaInset = inset
                        }
                }
            )
            .actionAreaShadow()
        }
    }
}

public struct SecondaryActionButton: View {
    private let title: Text
    private let action: () -> Void

    public init(_ title: Text, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        HStack {
            Spacer()
            Button(action: action) { title.bold() }
                .padding(8)
            Spacer()
        }
    }
}

public extension View {
    func actionAreaShadow() -> some View {
        background(
            Color(.secondarySystemGroupedBackground)
                .shadow(radius: 5)
                .ignoresSafeArea([.container, .keyboard], edges: .bottom)
        )
    }

    @ViewBuilder
    func actionAreaInset<BarContent: View>(@ViewBuilder _ barContent: () -> BarContent) -> some View {
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .bottom, spacing: 0) { FloatingActionArea(content: barContent) }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) { FloatingActionArea(content: barContent) }
        }
    }
}

/// The iOS 26 workaround mount: the bar ignores the keyboard safe-area region
/// (whose tracking is unreliable there) and is lifted by the keyboard overlap
/// measured through `UIKeyboardLayoutGuide`. The guide is constraint-driven,
/// so it reports exact geometry in every state — including frame-by-frame
/// while an interactive swipe drags the keyboard, where notifications are
/// silent until the gesture commits.
@available(iOS 26.0, *)
private struct KeyboardLiftedActionAreaInset<BarContent: View>: ViewModifier {
    let barContent: BarContent

    @State private var keyboardLift: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingActionArea { barContent }
                    .padding(.bottom, keyboardLift)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .background(
                KeyboardOverlapReader { overlap in
                    guard overlap != keyboardLift else { return }
                    keyboardLift = overlap
                }
            )
    }
}

/// Reports the height of the region between the keyboard's top edge and the
/// window's bottom safe area — 0 when no keyboard is up, and continuously
/// updated while the keyboard animates or tracks an interactive dismissal.
@available(iOS 26.0, *)
private struct KeyboardOverlapReader: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: AnchorView, context: Context) {
        uiView.onChange = onChange
    }

    final class AnchorView: UIView {
        var onChange: ((CGFloat) -> Void)?
        private var follower: FollowerView?
        private var notificationTokens: [NSObjectProtocol] = []

        deinit {
            notificationTokens.forEach(NotificationCenter.default.removeObserver)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            follower?.removeFromSuperview()
            follower = nil
            notificationTokens.forEach(NotificationCenter.default.removeObserver)
            notificationTokens = []
            guard let window else { return }

            let follower = FollowerView()
            follower.translatesAutoresizingMaskIntoConstraints = false
            follower.isUserInteractionEnabled = false
            follower.isHidden = true
            window.addSubview(follower)
            NSLayoutConstraint.activate([
                follower.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                follower.widthAnchor.constraint(equalToConstant: 1),
                follower.topAnchor.constraint(equalTo: window.keyboardLayoutGuide.topAnchor),
                follower.bottomAnchor.constraint(equalTo: window.bottomAnchor),
            ])
            follower.onLayout = { [weak self] in
                let duration = UIView.inheritedAnimationDuration
                DispatchQueue.main.async { self?.report(animatedOver: duration) }
            }
            self.follower = follower
            
            let names: [Notification.Name] = [
                UIResponder.keyboardWillShowNotification,
                UIResponder.keyboardDidShowNotification,
                UIResponder.keyboardWillHideNotification,
                UIResponder.keyboardDidHideNotification,
                UIResponder.keyboardWillChangeFrameNotification,
                UIResponder.keyboardDidChangeFrameNotification,
            ]
            for name in names {
                notificationTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                    let hiding = notification.name == UIResponder.keyboardWillHideNotification
                        || notification.name == UIResponder.keyboardDidHideNotification
                    let frameEnd = hiding ? nil : notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                    let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
                    DispatchQueue.main.async {
                        self?.report(notificationFrameEnd: frameEnd, animatedOver: duration)
                    }
                })
            }
        }

        private func report(notificationFrameEnd: CGRect? = nil, animatedOver duration: TimeInterval) {
            guard let window, let follower else { return }
            let bottomInset = window.safeAreaInsets.bottom
            let guideOverlap = max(0, follower.bounds.height - bottomInset)
            let frameOverlap: CGFloat
            if let frameEnd = notificationFrameEnd {
                let frameInWindow = window.convert(frameEnd, from: window.screen.coordinateSpace)
                frameOverlap = max(0, window.bounds.maxY - max(frameInWindow.minY, 0) - bottomInset)
            } else {
                frameOverlap = 0
            }
            let overlap = max(guideOverlap, frameOverlap)
            if duration > 0 {
                withAnimation(.easeOut(duration: duration)) { onChange?(overlap) }
            } else {
                onChange?(overlap)
            }
        }

        final class FollowerView: UIView {
            var onLayout: (() -> Void)?

            override func layoutSubviews() {
                super.layoutSubviews()
                onLayout?()
            }
        }
    }
}
