//
//  ActionArea.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit

/// Temporary appearance preferences shared with the app's Settings screen.
public enum ActionAreaAppearanceOverrides {
    // Retain the original storage key so expanding the toggle preserves its saved value.
    public static let roundedButtonsKey = "temporaryActionAreaRoundedPrimaryButtons"
}

private struct ActionAreaButtonCornerRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

private struct ActionAreaTextPaddingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var actionAreaButtonCornerRadius: CGFloat? {
        get { self[ActionAreaButtonCornerRadiusKey.self] }
        set { self[ActionAreaButtonCornerRadiusKey.self] = newValue }
    }

    var actionAreaTextPadding: CGFloat {
        get { self[ActionAreaTextPaddingKey.self] }
        set { self[ActionAreaTextPaddingKey.self] = newValue }
    }
}

/// Renders the shared footer, whether it is placed directly in a stack or by `actionAreaInset`.
public struct ActionArea<Content: View>: View {
    private let content: Content
    private let backgroundColor: Color

    public init(backgroundColor: Color = Color(.systemGroupedBackground), @ViewBuilder content: () -> Content) {
        self.content = content()
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        if Content.self != EmptyView.self {
            Group {
                if #available(iOS 26.0, *) {
                    GlassActionArea(content: content)
                } else {
                    ActionAreaContent(content: content)
                        .actionAreaShadow(backgroundColor: backgroundColor)
                }
            }
        }
    }
}

@available(iOS 26.0, *)
public struct ActionAreaHeader<Icon: View>: View {
    private let title: Text
    private let messages: [Text]
    private let showsIcon: Bool
    private let icon: Icon

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 24

    public init(_ title: Text, message: Text? = nil, showsIcon: Bool = true, @ViewBuilder icon: () -> Icon) {
        self.init(title, messages: message.map({ [$0] }) ?? [], showsIcon: showsIcon, icon: icon)
    }

    public init(_ title: Text, messages: [Text] = [], showsIcon: Bool = true, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.messages = messages
        self.showsIcon = showsIcon
        self.icon = icon()
    }

    public var body: some View {
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        headerIcon
                        title
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(messages.indices, id: \.self) { index in
                        messages[index]
                            .font(.subheadline)
                            .foregroundStyle(Color.primary.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding([.top, .horizontal], 8)
                .accessibilityElement(children: .combine)

                Divider()
                    .opacity(0.5)
                    .accessibilityHidden(true)
            }
        } else {
            HStack(spacing: 8) {
                headerIcon
                title
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var headerIcon: some View {
        if showsIcon {
            icon
                .font(.headline)
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
        }
    }
}

private enum ActionAreaLayout {
    static let roundedButtonContentPadding: CGFloat = 16
    static let squaredButtonContentPadding: CGFloat = 24
    static let leadingTextTopPadding: CGFloat = 24
    static let outerPadding: CGFloat = 14
    static let topCornerRadius: CGFloat = 40
    static let bottomCornerRadius: CGFloat = 48
}

private struct ActionAreaContent<Content: View>: View {
    let content: Content
    let topPadding: CGFloat
    let bottomPadding: CGFloat?
    let horizontalPadding: CGFloat?

    @State private var bottomSafeAreaInset: CGFloat = 0

    init(
        content: Content,
        topPadding: CGFloat = ActionAreaBackground.topPadding,
        bottomPadding: CGFloat? = nil,
        horizontalPadding: CGFloat? = nil
    ) {
        self.content = content
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.horizontalPadding = horizontalPadding
    }

    var body: some View {
        if Content.self != EmptyView.self {
            VStack(spacing: 12) {
                content
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding ?? (bottomSafeAreaInset > 0 ? 12 : 16))
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
        }
    }
}

private struct ActionAreaLeadingContentInsetKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

public extension View {
    func actionAreaLeadingContentInset(_ inset: CGFloat) -> some View {
        preference(key: ActionAreaLeadingContentInsetKey.self, value: max(0, inset))
    }

    func actionAreaShadow(backgroundColor: Color = Color(.systemGroupedBackground)) -> some View {
        background {
            if #available(iOS 26.0, *) {
                ActionAreaBackground(color: backgroundColor)
            } else {
                Color(.secondarySystemGroupedBackground)
                    .shadow(radius: 5)
                    .ignoresSafeArea([.container, .keyboard], edges: [.bottom, .horizontal])
            }
        }
    }

    func actionAreaInset<BarContent: View>(
        backgroundColor: Color = Color(.systemGroupedBackground),
        @ViewBuilder _ barContent: () -> BarContent
    ) -> some View {
        modifier(SeatedActionAreaInset(
            backgroundColor: backgroundColor,
            barContent: barContent(),
            isPresented: true,
            animationValue: false,
            animatesChanges: false
        ))
    }

    @available(iOS 26.0, *)
    func actionAreaInset<BarContent: View, Value: Equatable>(
        isPresented: Bool = true,
        animationValue: Value,
        backgroundColor: Color = Color(.systemGroupedBackground),
        @ViewBuilder _ barContent: () -> BarContent
    ) -> some View {
        modifier(SeatedActionAreaInset(
            backgroundColor: backgroundColor,
            barContent: barContent(),
            isPresented: isPresented,
            animationValue: animationValue,
            animatesChanges: true
        ))
    }
}

private struct SeatedActionAreaInset<BarContent: View, Value: Equatable>: ViewModifier {
    let backgroundColor: Color
    let barContent: BarContent
    let isPresented: Bool
    let animationValue: Value
    let animatesChanges: Bool

    @State private var isKeyboardVisible = false
    @State private var actionAreaHeight: CGFloat = 0

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content.modifier(GlassActionAreaInset(
                    barContent: barContent,
                    backgroundColor: backgroundColor,
                    isKeyboardVisible: isKeyboardVisible,
                    isPresented: isPresented,
                    animationValue: animationValue,
                    animatesChanges: animatesChanges
                ))
            } else {
                content
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear
                            .frame(height: isKeyboardVisible ? 0 : actionAreaHeight)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .overlay {
                        ActionArea(backgroundColor: backgroundColor) { barContent }
                            .onGeometryChange(for: CGFloat.self) { geometry in
                                geometry.size.height
                            } action: { height in
                                actionAreaHeight = height
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                    }
            }
        }
        .onKeyboardStateChange { state in
            isKeyboardVisible = state.height > 0
        }
    }
}

/// Keeps page keyboard avoidance separate from the footer's fixed bottom placement.
@available(iOS 26.0, *)
private struct GlassActionAreaInset<BarContent: View, Value: Equatable>: ViewModifier {
    let barContent: BarContent
    let backgroundColor: Color
    let isKeyboardVisible: Bool
    let isPresented: Bool
    let animationValue: Value
    let animatesChanges: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentBottomInset: CGFloat = 0

    private var transitionAnimation: Animation? {
        animatesChanges && !reduceMotion && !isKeyboardVisible
            ? .easeInOut(duration: 0.25) : nil
    }

    func body(content: Content) -> some View {
        // The form and its keyboard toolbar continue to respect the keyboard safe area.
        ZStack {
            content
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: isKeyboardVisible ? 0 : contentBottomInset)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .scrollEdgeEffectHidden(true, for: .bottom)
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            // This reader ignores only the keyboard, so its bottom inset remains the
            // container's home-indicator clearance even while the keyboard is visible.
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    if isPresented {
                        ActionArea(backgroundColor: backgroundColor) { barContent }
                            .contentTransition(animatesChanges ? .opacity : .identity)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                    }
                }
                .onGeometryChange(for: CGFloat.self) { footerGeometry in
                    // The page already avoids the container safe area. Reserve only
                    // the portion of the fixed footer that extends above that area.
                    max(0, footerGeometry.size.height - geometry.safeAreaInsets.bottom)
                } action: { inset in
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        contentBottomInset = inset
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height + geometry.safeAreaInsets.bottom,
                    alignment: .bottom
                )
                .allowsHitTesting(isPresented && !isKeyboardVisible)
                .accessibilityHidden(!isPresented || isKeyboardVisible)
                .animation(transitionAnimation, value: animationValue)
                .animation(transitionAnimation, value: isPresented)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}

@available(iOS 26.0, *)
private struct GlassActionArea<Content: View>: View {
    let content: Content

    @AppStorage(ActionAreaAppearanceOverrides.roundedButtonsKey)
    private var roundedButtons = false
    @State private var leadingContentInset: CGFloat = 0

    var body: some View {
        ActionAreaContent(
            content: content,
            topPadding: contentTopPadding,
            bottomPadding: contentPadding,
            horizontalPadding: contentPadding
        )
        .environment(\.actionAreaButtonCornerRadius, roundedButtons ? 26 : 10)
        .environment(\.actionAreaTextPadding, roundedButtons ? 8 : 0)
        .onPreferenceChange(ActionAreaLeadingContentInsetKey.self) { leadingContentInset = $0 }
        .glassEffect(.regular, in: UnevenRoundedRectangle(
            topLeadingRadius: ActionAreaLayout.topCornerRadius,
            bottomLeadingRadius: ActionAreaLayout.bottomCornerRadius,
            bottomTrailingRadius: ActionAreaLayout.bottomCornerRadius,
            topTrailingRadius: ActionAreaLayout.topCornerRadius,
            style: .continuous
        ))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -4)
        .padding(ActionAreaLayout.outerPadding)
    }

    private var contentTopPadding: CGFloat {
        let padding = leadingContentInset > 0 ? ActionAreaLayout.leadingTextTopPadding : contentPadding
        return max(0, padding - leadingContentInset)
    }

    private var contentPadding: CGFloat {
        roundedButtons
            ? ActionAreaLayout.roundedButtonContentPadding
            : ActionAreaLayout.squaredButtonContentPadding
    }
}
