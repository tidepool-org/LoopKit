//
//  VideoPlayView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 5/12/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct VideoPlayView<ThumbnailContent: View>: View {
    let stillImage: () -> ThumbnailContent
    let url: URL?
    let hasBeenPlayed: Binding<Bool>
    let includeStillImageBorder: Bool
    private var _autoPlay: Bool = true
    private var _overrideMuteSwitch: Bool = true
    
    // This from right out of the Design spec
    private let frameColor = Color(UIColor(red: 0.784, green: 0.784, blue: 0.784, alpha: 1))
    
    public init(url: URL?, stillImage: @autoclosure @escaping () -> ThumbnailContent, includeStillImageBorder: Bool = true) {
        self.url = url
        self.stillImage = stillImage
        self.includeStillImageBorder = includeStillImageBorder
        self.hasBeenPlayed = .false
    }

    public init(url: URL?, stillImage: @autoclosure @escaping () -> ThumbnailContent, hasBeenPlayed: Binding<Bool>, includeStillImageBorder: Bool = true) {
        self.url = url
        self.stillImage = stillImage
        self.includeStillImageBorder = includeStillImageBorder
        self.hasBeenPlayed = hasBeenPlayed
    }
    
    private init(_ other: Self, url: URL?? = nil, stillImage: (() -> ThumbnailContent)? = nil, hasBeenPlayed: Binding<Bool>? = nil, autoPlay: Bool? = nil, overrideMuteSwitch: Bool? = nil, includeStillImageBorder: Bool? = nil) {
        self.url = url ?? other.url
        self.stillImage = stillImage ?? other.stillImage
        self.hasBeenPlayed = hasBeenPlayed ?? other.hasBeenPlayed
        self.includeStillImageBorder = includeStillImageBorder ?? other.includeStillImageBorder
        self._autoPlay = autoPlay ?? other._autoPlay
        self._overrideMuteSwitch = overrideMuteSwitch ?? other._overrideMuteSwitch
    }

    public var body: some View {
        PopoverLink(destination: videoView) {
            if includeStillImageBorder {
                placeholderImage
                    .padding()
                    .border(frameColor, width: 1)
            } else {
                placeholderImage
            }
        }
        .fullScreen()
    }

    private var placeholderImage: some View {
        HStack {
            Spacer()
            ZStack {
                stillImage()
                Image(frameworkImage: "play-button", decorative: true)
            }
            Spacer()
        }
        .aspectRatio(CGSize(width: 16, height: 9), contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var videoView: some View {
        VideoView(url: url, autoPlay: _autoPlay, overrideMuteSwitch: _overrideMuteSwitch)
            .onDisappear { hasBeenPlayed.wrappedValue = true }
    }
    
    func autoPlay(_ enabled: Bool) -> Self {
        Self.init(self, autoPlay: enabled)
    }

    func overrideMuteSwitch(_ enabled: Bool) -> Self {
        Self.init(self, overrideMuteSwitch: enabled)
    }
}

fileprivate extension Binding where Value == Bool {
    static var `true` = Binding(get: { true }, set: { _ in })
    static var `false` = Binding(get: { false }, set: { _ in })
}
