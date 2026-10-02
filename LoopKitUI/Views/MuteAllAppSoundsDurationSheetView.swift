//
//  MuteAllAppSoundsDurationSheetView.swift
//  LoopKit
//
//  Created by Cameron Ingham on 7/1/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

public struct DurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let allowedDurations: [TimeInterval]
    
    @Binding private var duration: TimeInterval?
    @Binding private var durationWasSelected: Bool

    @State private var sheetContentHeight = Double(0)
    @State private var sheetActionContentHeight = Double(0)
    @State private var navigationBarHeight: CGFloat = 0
    @State private var sheetBottomSafeAreaInset: CGFloat = 0

    public init(allowedDurations: [TimeInterval], duration: Binding<TimeInterval?>, durationWasSelected: Binding<Bool>) {
        self.allowedDurations = allowedDurations
        self._duration = duration.projectedValue
        self._durationWasSelected = durationWasSelected.projectedValue
    }
    
    public var body: some View {
        if #available(iOS 26.0, *) {
            NavigationStack {
                VStack(spacing: 0) {
                    ScrollView {
                        MuteSoundsDurationForm(allowedDurations: allowedDurations, duration: $duration, showsTitle: false)
                            .readContentHeight(to: $sheetContentHeight)
                    }

                    muteButton
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: duration != nil)
                        .padding(16)
                        .readContentHeight(to: $sheetActionContentHeight)
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .navigationTitle("Mute All App Sounds")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        cancelButton
                    }
                }
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.safeAreaInsets.top
                } action: { height in
                    navigationBarHeight = height
                }
            }
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.safeAreaInsets.bottom
            } action: { inset in
                sheetBottomSafeAreaInset = inset
            }
            .sheetDetent(height: max(1, sheetContentHeight + sheetActionContentHeight + Double(navigationBarHeight - sheetBottomSafeAreaInset)))
        } else {
            VStack {
                ScrollView {
                    MuteSoundsDurationForm(allowedDurations: allowedDurations, duration: $duration, showsTitle: true)
                        .readContentHeight(to: $sheetContentHeight)
                }

                ActionArea(backgroundColor: Color(.systemBackground)) {
                    muteButton
                    cancelButton
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                }
                .readContentHeight(to: $sheetActionContentHeight)
            }
            .sheetDetent(height: sheetContentHeight + sheetActionContentHeight)
        }
    }

    private var muteButton: some View {
        Button {
            durationWasSelected = true
        } label: {
            Text("Mute All App Sounds")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ActionButtonStyle(.primary))
        .frame(maxWidth: .infinity)
        .disabled(duration == nil)
    }

    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
            duration = nil
        }
    }
}

private struct MuteSoundsDurationForm: View {
    @Environment(\.appName) private var appName

    let allowedDurations: [TimeInterval]
    @Binding var duration: TimeInterval?
    let showsTitle: Bool

    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsTitle {
                Text("Mute All App Sounds")
                    .font(.title2.weight(.bold))
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(
                    String(
                        format: NSLocalizedString(
                            "Temporarily silence all sounds from the %1$@ app.",
                            comment: "Silence all app sounds description (1: appName)"
                        ),
                        appName
                    )
                )
                .padding(.horizontal)

                Callout(
                    .warning,
                    title: Text("Critical alerts will be muted"),
                    message: Text("All app sounds, including sounds for all critical alerts such as Urgent Low, Sensor Fail, Pump Expiration, and others will NOT sound for your selected time duration.")
                )

                Text("If vibration is enabled on your device, all alerts will still vibrate. Your insulin pump and CGM hardware may still sound.")
                    .padding(.horizontal)
            }

            Picker(selection: $duration) {
                Text("Select")
                    .tag(nil as TimeInterval?)

                ForEach(allowedDurations, id: \.self) { duration in
                    if let durationString = Self.formatter.string(from: duration) {
                        Text(durationString)
                            .tag(duration as TimeInterval?)
                    }
                }
            } label: {
                EmptyView()
            }
            .font(.title3)
            .pickerStyle(.wheel)
            .frame(height: 170)
            .padding(.horizontal)
        }
        .padding(.top, showsTitle ? 32 : 16)
    }
}

public struct ConfirmationSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors
    
    private let resumeDate: Date
    
    public init(resumeDate: Date) {
        self.resumeDate = resumeDate
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.slash.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 41)
                .foregroundStyle(guidanceColors.critical)
            
            VStack(spacing: 4) {
                Text("All App Sounds Muted")
                    .font(.title2.bold())
                
                Text("until ") + Text(resumeDate.formatted(date: .omitted, time: .shortened))
            }
            
            Button("Close") {
                dismiss()
            }
            .font(.body.bold())
            .padding(.top, 32)
        }
        .ignoresSafeArea(edges: .bottom)
        .padding(.horizontal)
        .padding(.top, 40)
        .padding(.bottom, 2)
        .presentationHuggingDetent()
        .task {
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 3)
            dismiss()
        }
    }
}

public extension View {
    func presentationHuggingDetent() -> some View {
        HuggingDetentView { self }
    }
}

public extension View {
    @ViewBuilder
    func sheetDetent(height: Double) -> some View {
        self
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
    }
}

private struct HuggingDetentView<Content: View>: View {
    
    @State private var sheetContentHeight: Double = 0
    
    private let content: Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        content
            .readContentHeight()
            .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                if let height {
                    sheetContentHeight = height
                }
            }
            .sheetDetent(height: sheetContentHeight)
    }
}

public struct ContentHeightPreferenceKey: PreferenceKey {
    public static var defaultValue: CGFloat?

    public static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        guard let nextValue = nextValue() else { return }
        value = nextValue
    }
}

public struct ReadContentHeightModifier: ViewModifier {
    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: ContentHeightPreferenceKey.self, value: geometry.size.height)
        }
    }

    public func body(content: Content) -> some View {
        content.background(sizeView)
    }
}

public extension View {
    func readContentHeight() -> some View {
        self
            .modifier(ReadContentHeightModifier())
    }
    
    func readContentHeight(to contentHeight: Binding<Double>) -> some View {
        self
            .modifier(ReadContentHeightModifier())
            .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                if let height {
                    contentHeight.wrappedValue = height
                }
            }
    }
}
