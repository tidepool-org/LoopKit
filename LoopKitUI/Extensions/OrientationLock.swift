//
//  OrientationLock.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/28/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public protocol DeviceOrientationController: AnyObject {
    var supportedInterfaceOrientations: UIInterfaceOrientationMask { get set }
    func setOriginallySupportedInferfaceOrientations()
}

/// A class whose lifetime defines the application's supported interface orientations.
///
/// Use the `supportedInterfaceOrientations` modifier on a SwiftUI view to lock its orientation.
/// To function, `OrientationLock.deviceOrientationController` must be assigned prior to use.
public final class OrientationLock {
    /// The global controller for device orientation.
    /// The property must be assigned prior to instantiating any OrientationLock.
    public static weak var deviceOrientationController: DeviceOrientationController?

    fileprivate init(_ supportedInterfaceOrientations: UIInterfaceOrientationMask) {
        guard let deviceOrientationController = Self.deviceOrientationController else {
            assertionFailure("OrientationLock.deviceOrientationController must be assigned prior to constructing an OrientationLock")
            return
        }

        deviceOrientationController.supportedInterfaceOrientations = supportedInterfaceOrientations
    }
    
    func setOriginallySupportedInferfaceOrientations() {
        Self.deviceOrientationController?.setOriginallySupportedInferfaceOrientations()
    }
}

extension View {
    /// Use the `supportedInterfaceOrientations` modifier on a SwiftUI view to lock its orientation.
    /// To function, `OrientationLock.deviceOrientationController` must be assigned prior to use.
    public func supportedInterfaceOrientations(_ supportedInterfaceOrientations: UIInterfaceOrientationMask) -> some View {
        OrientationLocked(supportedInterfaceOrientations: supportedInterfaceOrientations, content: self)
    }
}

private struct OrientationLocked<Content: View>: View {
    // Annotated with `@State` to ensure SwiftUI keeps the object alive for the duration of the view's lifetime
    @State var orientationLock: OrientationLock
    var content: Content

    init(supportedInterfaceOrientations: UIInterfaceOrientationMask, content: Content) {
        self._orientationLock = State(wrappedValue: OrientationLock(supportedInterfaceOrientations))
        self.content = content
    }

    var body: some View {
        content
            .onDisappear { orientationLock.setOriginallySupportedInferfaceOrientations() }
    }
}
