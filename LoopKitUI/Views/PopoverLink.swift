//
//  PopoverLink.swift
//
//  Created by Manuel Weiel on 09.07.20.
//
// From https://manuel.weiel.eu/bringing-the-simplicity-of-navigationlink-to-popovers/

import SwiftUI

public struct PopoverLink<Label, Destination> : View where Label : View, Destination : View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private let destination: Destination
    private let label: Label
    private var isActive: Binding<Bool>?
    private var isFullScreen: Bool = false
    @State private var internalIsActive = false

    public init(_ localizedText: Text, destination: Destination) where Label == Text {
        self.init(destination: destination, label: { localizedText })
    }
    
    /// Creates an instance that presents `destination`.
    public init(destination: Destination, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }

    /// Creates an instance that presents `destination` when active.
    public init(destination: Destination, isActive: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
        self.isActive = isActive
    }
    
    private init(_ other: PopoverLink, isFullScreen: Bool) {
        self.destination = other.destination
        self.isActive = other.isActive
        self.label = other.label
        self.isFullScreen = isFullScreen
    }

    private func popoverButton(isPresented: Binding<Bool>) -> some View {
        Button {
            isPresented.wrappedValue = true
        } label: {
            label
        }
    }

    /// The content and behavior of the view.
    public var body: some View {
        let isPresented = isActive ?? $internalIsActive

        if isFullScreen {
            popoverButton(isPresented: isPresented).fullScreenCover(isPresented: isPresented) {
                destination
            }
        } else {
            if horizontalSizeClass == .compact {
                popoverButton(isPresented: isPresented).sheet(isPresented: isPresented) {
                    destination
                }
            } else {
                popoverButton(isPresented: isPresented).popover(isPresented: isPresented) {
                    destination
                }
            }
        }
    }
}

extension PopoverLink {
    public func fullScreen() -> PopoverLink {
        PopoverLink(self, isFullScreen: true)
    }
}
