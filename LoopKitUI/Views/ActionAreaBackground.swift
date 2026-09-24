//
//  ActionAreaBackground.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct ActionAreaBackground: View {
    let color: Color

    static let topPadding: CGFloat = 16
    private static let fadeExtension: CGFloat = 32

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if reduceTransparency {
                color
            } else {
                Rectangle()
                    .fill(.thinMaterial)
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black.opacity(0.10), location: 0.20),
                                    .init(color: .black.opacity(0.38), location: 0.45),
                                    .init(color: .black.opacity(0.74), location: 0.70),
                                    .init(color: .black.opacity(0.94), location: 0.87),
                                    .init(color: .black, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: Self.fadeExtension + Self.topPadding)

                            // Both actions have full blur coverage while remaining translucent.
                            Color.black
                        }
                    }
                    // Extend only the material, preserving the footer and scroll spacing.
                    .padding(.top, -Self.fadeExtension)
            }
        }
        .ignoresSafeArea([.container, .keyboard], edges: [.bottom, .horizontal])
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
