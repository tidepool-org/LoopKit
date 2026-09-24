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

extension EnvironmentValues {
    var actionAreaButtonCornerRadius: CGFloat? {
        get { self[ActionAreaButtonCornerRadiusKey.self] }
        set { self[ActionAreaButtonCornerRadiusKey.self] = newValue }
    }
}

/// Renders the shared footer, whether it is placed directly in a stack or by `actionAreaInset`.
public struct ActionArea<Content: View>: View {
    private let content: Content
    private let backgroundColor: Color
    private let containerBottomSafeAreaInset: CGFloat

    public init(backgroundColor: Color = Color(.systemGroupedBackground), @ViewBuilder content: () -> Content) {
        self.content = content()
        self.backgroundColor = backgroundColor
        // Direct stack placement already respects the container safe area.
        self.containerBottomSafeAreaInset = 0
    }

    fileprivate init(content: Content, backgroundColor: Color, containerBottomSafeAreaInset: CGFloat) {
        self.content = content
        self.backgroundColor = backgroundColor
        self.containerBottomSafeAreaInset = containerBottomSafeAreaInset
    }

    public var body: some View {
        if Content.self != EmptyView.self {
            Group {
                if #available(iOS 26.0, *) {
                    GlassActionArea(
                        content: content,
                        bottomPadding: max(16, containerBottomSafeAreaInset - 8)
                    )
                } else {
                    ActionAreaContent(content: content)
                        .actionAreaShadow(backgroundColor: backgroundColor)
                }
            }
        }
    }
}

private enum ActionAreaLayout {
    static let horizontalPadding: CGFloat = 16
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

private struct ActionAreaLeadingTextButtonKey: PreferenceKey {
    static var defaultValue: Bool { false }

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

public extension View {
    /// Marks action content that starts with a text-only button. On iOS 26+, the enclosing
    /// action area uses a smaller top inset without changing the button's own padding.
    func actionAreaHasLeadingTextButton(_ hasLeadingTextButton: Bool = true) -> some View {
        preference(key: ActionAreaLeadingTextButtonKey.self, value: hasLeadingTextButton)
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
        modifier(SeatedActionAreaInset(backgroundColor: backgroundColor, barContent: barContent()))
    }
}

private struct SeatedActionAreaInset<BarContent: View>: ViewModifier {
    let backgroundColor: Color
    let barContent: BarContent

    @State private var isKeyboardVisible = false
    @State private var actionAreaHeight: CGFloat = 0

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content.modifier(GlassActionAreaInset(
                    barContent: barContent,
                    backgroundColor: backgroundColor,
                    isKeyboardVisible: isKeyboardVisible
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
private struct GlassActionAreaInset<BarContent: View>: ViewModifier {
    let barContent: BarContent
    let backgroundColor: Color
    let isKeyboardVisible: Bool

    @State private var contentBottomInset: CGFloat = 0

    func body(content: Content) -> some View {
        // The form and its keyboard toolbar continue to respect the keyboard safe area.
        ZStack {
            content
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: isKeyboardVisible ? 0 : contentBottomInset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .scrollEdgeEffectHidden(true, for: .bottom)
        .overlay {
            // This reader ignores only the keyboard, so its bottom inset remains the
            // container's home-indicator clearance even while the keyboard is visible.
            GeometryReader { geometry in
                ActionArea(
                    content: barContent,
                    backgroundColor: backgroundColor,
                    containerBottomSafeAreaInset: geometry.safeAreaInsets.bottom
                )
                .onGeometryChange(for: CGFloat.self) { footerGeometry in
                    // The page already avoids the container safe area. Reserve only
                    // the portion of the fixed footer that extends above that area.
                    max(0, footerGeometry.size.height - geometry.safeAreaInsets.bottom)
                } action: { inset in
                    contentBottomInset = inset
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.container, edges: .bottom)
                .allowsHitTesting(!isKeyboardVisible)
                .accessibilityHidden(isKeyboardVisible)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}

@available(iOS 26.0, *)
private struct GlassActionArea<Content: View>: View {
    let content: Content
    let bottomPadding: CGFloat

    @AppStorage(ActionAreaAppearanceOverrides.roundedButtonsKey)
    private var roundedButtons = false
    @State private var hasLeadingTextButton = false
    @State private var bottomCornerRadii: ActionAreaBottomCornerRadii?
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ActionAreaContent(
            content: content,
            topPadding: hasLeadingTextButton ? 8 : ActionAreaBackground.topPadding,
            bottomPadding: roundedButtons ? ActionAreaLayout.horizontalPadding : bottomPadding,
            horizontalPadding: ActionAreaLayout.horizontalPadding
        )
        .environment(\.actionAreaButtonCornerRadius, buttonCornerRadius)
        .onPreferenceChange(ActionAreaLeadingTextButtonKey.self) { hasLeadingTextButton = $0 }
        .glassEffect(.regular, in: glassShape)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -4)
        .background {
            ActionAreaWindowCornerReader(cornerRadii: $bottomCornerRadii)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(8)
    }

    private var buttonCornerRadius: CGFloat {
        roundedButtons ? 26 : 10
    }

    private var defaultGlassCornerRadius: CGFloat {
        roundedButtons ? buttonCornerRadius + ActionAreaLayout.horizontalPadding : cardCornerRadius
    }

    private var glassShape: AnyShape {
        let leadingRadius = layoutDirection == .leftToRight ? bottomCornerRadii?.left : bottomCornerRadii?.right
        let trailingRadius = layoutDirection == .leftToRight ? bottomCornerRadii?.right : bottomCornerRadii?.left
        let uniformLeadingInset = (layoutDirection == .leftToRight
            ? bottomCornerRadii?.leftHasUniformInset : bottomCornerRadii?.rightHasUniformInset) ?? false
        let uniformTrailingInset = (layoutDirection == .leftToRight
            ? bottomCornerRadii?.rightHasUniformInset : bottomCornerRadii?.leftHasUniformInset) ?? false
        let base = ConcentricRectangle(
            uniformTopCorners: .fixed(defaultGlassCornerRadius),
            bottomLeadingCorner: uniformLeadingInset ? .fixed(cardCornerRadius) : bottomCornerStyle(windowRadius: leadingRadius),
            bottomTrailingCorner: uniformTrailingInset ? .fixed(cardCornerRadius) : bottomCornerStyle(windowRadius: trailingRadius)
        )
        guard uniformLeadingInset || uniformTrailingInset else {
            return AnyShape(base)
        }
        // Recover the container radius from UIKit's concentric radius and its equal inset.
        // Offset the actual curve: reducing a continuous radius is not a constant-width inset.
        let outline = base.intersection(ActionAreaUniformInsetShape(
            inset: 8,
            leadingWindowRadius: uniformLeadingInset ? (leadingRadius ?? 0) + 8 : 0,
            trailingWindowRadius: uniformTrailingInset ? (trailingRadius ?? 0) + 8 : 0
        ))
        return roundedButtons
            ? AnyShape(ActionAreaSmoothGlassOutline(outline: outline))
            : AnyShape(outline)
    }

    private func bottomCornerStyle(windowRadius: CGFloat?) -> Edge.Corner.Style {
        // Preserve native curves where the footer reaches a display corner. Away from
        // those corners, including landscape side insets, wrap the rounded button instead.
        if let windowRadius, windowRadius > cardCornerRadius {
            return .fixed(windowRadius)
        }
        return .concentric(minimum: .fixed(defaultGlassCornerRadius))
    }
}

/// Rounds crossings where a short footer's top curve meets its device-matched bottom curve.
@available(iOS 26.0, *)
private struct ActionAreaSmoothGlassOutline<Outline: Shape>: Shape {
    let outline: Outline

    var layoutDirectionBehavior: LayoutDirectionBehavior { outline.layoutDirectionBehavior }

    func path(in rect: CGRect) -> Path {
        let path = outline.path(in: rect)
        guard !rect.isEmpty else { return path }
        // Spread the join over a broader arc, leaving an interior even in short footers.
        let radius = min(32, min(rect.width, rect.height) * 0.4)
        let stroke = StrokeStyle(lineWidth: 2 * radius, lineCap: .round, lineJoin: .round)
        // Inset and expand by the same distance. Smooth curves retain their outline;
        // sharp intersections become tangent arcs without increasing the footer padding.
        let interior = path.subtracting(path.strokedPath(stroke))
        return interior.union(interior.strokedPath(stroke))
    }
}

/// Offsets the native continuous outline by a constant distance, including through the bend.
/// RoundedRectangle.inset(by:) only reduces its radius, which pinches the gap along that curve.
@available(iOS 26.0, *)
private struct ActionAreaUniformInsetShape: Shape {
    let inset: CGFloat
    let leadingWindowRadius: CGFloat
    let trailingWindowRadius: CGFloat

    var layoutDirectionBehavior: LayoutDirectionBehavior { .mirrors }

    func path(in rect: CGRect) -> Path {
        let bottom = rect.maxY + inset
        let top = min(rect.minY - inset, bottom - 2 * max(leadingWindowRadius, trailingWindowRadius))
        let referenceRect = CGRect(
            x: rect.minX - inset,
            y: top,
            width: rect.width + 2 * inset,
            height: bottom - top
        )
        let outline = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: leadingWindowRadius,
            bottomTrailingRadius: trailingWindowRadius,
            topTrailingRadius: 0,
            style: .continuous
        ).path(in: referenceRect)
        // A centered 2x-inset stroke removes exactly `inset` from inside the boundary.
        let edge = outline.strokedPath(StrokeStyle(lineWidth: 2 * inset, lineCap: .butt, lineJoin: .round))
        return outline.subtracting(edge)
    }
}

private struct ActionAreaBottomCornerRadii: Equatable {
    let left: CGFloat
    let right: CGFloat
    let leftHasUniformInset: Bool
    let rightHasUniformInset: Bool
}

/// Reads native concentric radii at the window level. Duo's presented page container can
/// report square bottom corners even when the display corner behind it is rounded.
@available(iOS 26.0, *)
private struct ActionAreaWindowCornerReader: UIViewRepresentable {
    @Binding var cornerRadii: ActionAreaBottomCornerRadii?

    func makeUIView(context: Context) -> CornerReaderView {
        CornerReaderView()
    }

    func updateUIView(_ uiView: CornerReaderView, context: Context) {
        uiView.onCornerRadiiChange = { cornerRadii = $0 }
        uiView.setNeedsLayout()
    }

    static func dismantleUIView(_ uiView: CornerReaderView, coordinator: ()) {
        uiView.detach()
    }

    final class CornerReaderView: UIView {
        var onCornerRadiiChange: ((ActionAreaBottomCornerRadii) -> Void)?
        private let windowCornerView = WindowCornerView()

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
            windowCornerView.onCornerRadiiChange = { [weak self] corners in
                self?.onCornerRadiiChange?(corners)
            }
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            windowCornerView.removeFromSuperview()
            if let window {
                // An invisible sibling avoids inheriting the presented page's square corners.
                window.addSubview(windowCornerView)
                setNeedsLayout()
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let window else { return }
            let footerFrame = convert(bounds, to: window)
            windowCornerView.footerFrame = footerFrame
            // A footer-height reference can clamp the resolved radius to half its height.
            // Extend only its top so UIKit measures the native bottom curves without that
            // cap. The side and bottom positions still include the footer's outer inset.
            windowCornerView.frame = CGRect(
                x: footerFrame.minX,
                y: window.bounds.minY,
                width: footerFrame.width,
                height: max(0, footerFrame.maxY - window.bounds.minY)
            )
            windowCornerView.setNeedsLayout()
        }

        func detach() {
            onCornerRadiiChange = nil
            windowCornerView.removeFromSuperview()
        }
    }

    private final class WindowCornerView: UIView {
        var onCornerRadiiChange: ((ActionAreaBottomCornerRadii) -> Void)?
        var footerFrame: CGRect = .zero
        private var lastCornerRadii: ActionAreaBottomCornerRadii?

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
            backgroundColor = .clear
            cornerConfiguration = .uniformTopRadius(
                .fixed(Double(cardCornerRadius)),
                bottomLeftRadius: .containerConcentric(),
                bottomRightRadius: .containerConcentric()
            )
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let window, !bounds.isEmpty else { return }
            // UIKit invalidates layout when these native radii change, including pose changes
            // that leave the footer's size unchanged.
            let leftRadius = effectiveRadius(corner: .bottomLeft)
            let rightRadius = effectiveRadius(corner: .bottomRight)
            let tolerance = 1 / max(traitCollection.displayScale, 1)
            let bottomIsInset = abs(window.bounds.maxY - footerFrame.maxY - 8) <= tolerance
            // Use a parallel curve only where the side and bottom both sit 8pt from the
            // window. Sheets and asymmetric toolbar/camera margins retain native concentricity.
            let corners = ActionAreaBottomCornerRadii(
                left: leftRadius,
                right: rightRadius,
                leftHasUniformInset: bottomIsInset && leftRadius > cardCornerRadius
                    && abs(footerFrame.minX - window.bounds.minX - 8) <= tolerance,
                rightHasUniformInset: bottomIsInset && rightRadius > cardCornerRadius
                    && abs(window.bounds.maxX - footerFrame.maxX - 8) <= tolerance
            )
            guard corners != lastCornerRadii else { return }
            lastCornerRadii = corners
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil, self.lastCornerRadii == corners else { return }
                self.onCornerRadiiChange?(corners)
            }
        }
    }
}
