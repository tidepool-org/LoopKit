//
//  ActionArea.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

private struct ActionAreaTextPaddingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var actionAreaTextPadding: CGFloat {
        get { self[ActionAreaTextPaddingKey.self] }
        set { self[ActionAreaTextPaddingKey.self] = newValue }
    }
}

/// Renders the shared footer, whether it is placed directly in a stack or by `actionAreaInset`.
public struct ActionArea<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if Content.self != EmptyView.self {
            if #available(iOS 18.0, *) {
                // A builder such as `if let … { Button } else { EmptyView() }` can resolve to no views.
                Group(subviews: content) { subviews in
                    if !subviews.isEmpty {
                        area(subviews)
                    }
                }
            } else {
                area(content)
            }
        }
    }

    @ViewBuilder
    private func area(_ content: some View) -> some View {
        if #available(iOS 26.0, *) {
            GlassActionArea(content: content)
        } else {
            ActionAreaContent(content: content)
                .background {
                    Color(.secondarySystemGroupedBackground)
                        .shadow(radius: 5)
                        .ignoresSafeArea([.container, .keyboard], edges: [.bottom, .horizontal])
                }
        }
    }
}

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
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
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
    static let contentPadding: CGFloat = 16
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
        topPadding: CGFloat = ActionAreaLayout.contentPadding,
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

private struct InlineActionAreaKey: EnvironmentKey {
    static let defaultValue: AnyView? = nil
}

private struct InlineActionAreaMarginKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

private extension EnvironmentValues {
    var inlineActionArea: AnyView? {
        get { self[InlineActionAreaKey.self] }
        set { self[InlineActionAreaKey.self] = newValue }
    }

    var inlineActionAreaMargin: CGFloat? {
        get { self[InlineActionAreaMarginKey.self] }
        set { self[InlineActionAreaMarginKey.self] = newValue }
    }
}

/// Place at the end of scrolling content and use `actionAreaInset(inlineAtAccessibilitySizes: true)`
/// on that page. At accessibility text sizes the footer scrolls here instead of covering the page.
public struct ActionAreaInlineSlot: View {
    @Environment(\.inlineActionArea) private var inlineActionArea
    private let margin: CGFloat

    /// The space beside and below an inline glass card. Use 0 in an already inset list row.
    public init(margin: CGFloat = 16) {
        self.margin = margin
    }

    public var body: some View {
        if let inlineActionArea {
            inlineActionArea
                .environment(\.inlineActionAreaMargin, margin)
                // A list row otherwise fires every default-style button in it on a single tap.
                .buttonStyle(.borderless)
        }
    }
}

public extension View {
    func actionAreaLeadingContentInset(_ inset: CGFloat) -> some View {
        preference(key: ActionAreaLeadingContentInsetKey.self, value: max(0, inset))
    }

    /// Pins the footer by default. Opt in to inline placement at accessibility text sizes only
    /// when the page contains an `ActionAreaInlineSlot`.
    func actionAreaInset<BarContent: View>(
        inlineAtAccessibilitySizes: Bool = false,
        @ViewBuilder _ barContent: () -> BarContent
    ) -> some View {
        modifier(SeatedActionAreaInset(
            barContent: barContent(),
            isPresented: true,
            animationValue: false,
            animatesChanges: false,
            inlineAtAccessibilitySizes: inlineAtAccessibilitySizes
        ))
    }

    /// Shows the footer only while `isPresented`, and swaps the card whenever `animationValue`
    /// changes. Before iOS 26 the pinned footer changes without the cross-fade.
    func actionAreaInset<BarContent: View, Value: Hashable>(
        isPresented: Bool = true,
        animationValue: Value,
        inlineAtAccessibilitySizes: Bool = false,
        @ViewBuilder _ barContent: () -> BarContent
    ) -> some View {
        modifier(SeatedActionAreaInset(
            barContent: barContent(),
            isPresented: isPresented,
            animationValue: animationValue,
            animatesChanges: true,
            inlineAtAccessibilitySizes: inlineAtAccessibilitySizes
        ))
    }
}

private struct SeatedActionAreaInset<BarContent: View, Value: Hashable>: ViewModifier {
    let barContent: BarContent
    let isPresented: Bool
    let animationValue: Value
    let animatesChanges: Bool
    let inlineAtAccessibilitySizes: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var keyboard = KeyboardOverlap()
    @State private var actionAreaHeight: CGFloat = 0

    private var showsInlineActionArea: Bool {
        inlineAtAccessibilitySizes && dynamicTypeSize.isAccessibilitySize
    }

    private var showsPinnedActionArea: Bool {
        isPresented && !showsInlineActionArea
    }

    func body(content: Content) -> some View {
        // Keep the page in the same hierarchy when Dynamic Type changes, preserving its form state.
        let page = content.environment(\.inlineActionArea, showsInlineActionArea
            ? AnyView(InlineActionArea(
                barContent: barContent,
                isPresented: isPresented,
                isKeyboardVisible: keyboard.isVisible,
                animationValue: animationValue,
                animatesChanges: animatesChanges
            ))
            : nil)

        Group {
            if #available(iOS 26.0, *) {
                page.modifier(GlassActionAreaInset(
                    barContent: barContent,
                    keyboard: keyboard,
                    isPresented: showsPinnedActionArea,
                    animationValue: animationValue,
                    animatesChanges: animatesChanges
                ))
            } else {
                page
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear
                            .frame(height: keyboard.coversFooter || !showsPinnedActionArea ? 0 : actionAreaHeight)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        if showsPinnedActionArea {
                            ActionArea { barContent }
                                .onGeometryChange(for: CGFloat.self) { geometry in
                                    geometry.size.height
                                } action: { height in
                                    actionAreaHeight = height
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .ignoresSafeArea(keyboard.isStrip ? [] : .keyboard, edges: .bottom)
                                .allowsHitTesting(!keyboard.coversFooter)
                                .accessibilityHidden(keyboard.coversFooter)
                        }
                    }
            }
        }
        .onKeyboardStateChange { state in
            keyboard = KeyboardOverlap(height: state.height)
        }
    }
}

/// A software keyboard covers the seated footer. A hardware keyboard leaves only a
/// shortcut or accessory strip on screen, so the footer rises above it instead.
private struct KeyboardOverlap {
    private static let maximumStripHeight: CGFloat = 150

    var height: CGFloat = 0

    var isVisible: Bool { height > 0 }
    var coversFooter: Bool { height > Self.maximumStripHeight }
    var isStrip: Bool { isVisible && !coversFooter }
}

private struct InlineActionArea<BarContent: View, Value: Hashable>: View {
    let barContent: BarContent
    let isPresented: Bool
    let isKeyboardVisible: Bool
    let animationValue: Value
    let animatesChanges: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var transitionAnimation: Animation? {
        animatesChanges && !reduceMotion && !isKeyboardVisible
            ? .easeInOut(duration: 0.25) : nil
    }

    var body: some View {
        // Keep the slot alive while hidden so a footer that arrives later can animate in place.
        VStack(spacing: 0) {
            if isPresented {
                ActionAreaCard(barContent: barContent, animationValue: animationValue, animatesChanges: animatesChanges)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
            }
        }
        .environment(\.inlineActionArea, nil)
        .animation(transitionAnimation, value: animationValue)
        .animation(transitionAnimation, value: isPresented)
    }
}

/// Swaps the whole card when the footer's state changes and cross-fades the two, bottom aligned.
/// Resizing a single card instead lays its new rows out against the card's moving top edge,
/// so they hang below the glass and land on the outgoing rows partway through the animation.
private struct ActionAreaCard<BarContent: View, Value: Hashable>: View {
    let barContent: BarContent
    let animationValue: Value
    let animatesChanges: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ActionArea { barContent }
                .id(animationValue)
                .transition(.opacity)
        }
        .contentTransition(animatesChanges ? .opacity : .identity)
    }
}

/// Keeps page keyboard avoidance separate from the footer's fixed bottom placement.
@available(iOS 26.0, *)
private struct GlassActionAreaInset<BarContent: View, Value: Hashable>: ViewModifier {
    let barContent: BarContent
    let keyboard: KeyboardOverlap
    let isPresented: Bool
    let animationValue: Value
    let animatesChanges: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var footer = FooterLayout()

    private struct FooterLayout: Equatable {
        var height: CGFloat = 0
        var containerBottomInset: CGFloat = 0
    }

    private var transitionAnimation: Animation? {
        animatesChanges && !reduceMotion && !keyboard.isVisible
            ? .easeInOut(duration: 0.25) : nil
    }

    // The page already avoids the container safe area, or the whole strip the footer rests on.
    private var contentBottomInset: CGFloat {
        if keyboard.coversFooter { return 0 }
        if keyboard.isStrip { return footer.height }
        return max(0, footer.height - footer.containerBottomInset)
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: contentBottomInset)
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
                        ActionAreaCard(barContent: barContent, animationValue: animationValue, animatesChanges: animatesChanges)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                    }
                }
                .onGeometryChange(for: FooterLayout.self) { footerGeometry in
                    FooterLayout(height: footerGeometry.size.height, containerBottomInset: geometry.safeAreaInsets.bottom)
                } action: { layout in
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        footer = layout
                    }
                }
                .padding(.bottom, keyboard.isStrip ? keyboard.height : 0)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height + geometry.safeAreaInsets.bottom,
                    alignment: .bottom
                )
                .allowsHitTesting(isPresented && !keyboard.coversFooter)
                .accessibilityHidden(!isPresented || keyboard.coversFooter)
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

    @Environment(\.inlineActionAreaMargin) private var inlineMargin
    @State private var leadingContentInset: CGFloat = 0

    var body: some View {
        let card = ActionAreaContent(
            content: content,
            topPadding: contentTopPadding,
            bottomPadding: ActionAreaLayout.contentPadding,
            horizontalPadding: ActionAreaLayout.contentPadding
        )
        .environment(\.actionAreaTextPadding, 8)
        .onPreferenceChange(ActionAreaLeadingContentInsetKey.self) { leadingContentInset = $0 }
        .glassEffect(.regular, in: cardShape)

        if let inlineMargin {
            card
                .clipShape(cardShape)
                .padding(EdgeInsets(top: 0, leading: inlineMargin, bottom: inlineMargin, trailing: inlineMargin))
        } else {
            card
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -4)
                .padding(ActionAreaLayout.outerPadding)
        }
    }

    private var cardShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: ActionAreaLayout.topCornerRadius,
            bottomLeadingRadius: ActionAreaLayout.bottomCornerRadius,
            bottomTrailingRadius: ActionAreaLayout.bottomCornerRadius,
            topTrailingRadius: ActionAreaLayout.topCornerRadius,
            style: .continuous
        )
    }

    private var contentTopPadding: CGFloat {
        let padding = leadingContentInset > 0 ? ActionAreaLayout.leadingTextTopPadding : ActionAreaLayout.contentPadding
        return max(0, padding - leadingContentInset)
    }
}
