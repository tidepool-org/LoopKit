//
//  OrientationLock.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/28/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

/// To enable orientation locking via OrientationLock, the application's delegate must conform to DeviceOrientationController.
public protocol DeviceOrientationController: AnyObject {
    var supportedInterfaceOrientations: UIInterfaceOrientationMask { get set }
}

/// A class whose lifetime defines the application's supported interface orientations.
///
/// Construct an OrientationLock as a `@State` property in a SwiftUI view to constrain the view's supported orientations.
/// To function, `OrientationLock.deviceOrientationController` must be assigned prior to use.
public final class OrientationLock {
    private let originalSupportedInterfaceOrientations: UIInterfaceOrientationMask

    /// The global controller for device orientation.
    /// The property must be assigned prior to instantiating any OrientationLock.
    public static weak var deviceOrientationController: DeviceOrientationController?

    public init(_ supportedInterfaceOrientations: UIInterfaceOrientationMask) {
        originalSupportedInterfaceOrientations = Self.deviceOrientationController?.supportedInterfaceOrientations ?? .allButUpsideDown
        Self.deviceOrientationController?.supportedInterfaceOrientations = supportedInterfaceOrientations
    }

    deinit {
        Self.deviceOrientationController?.supportedInterfaceOrientations = originalSupportedInterfaceOrientations
    }
}

