//
//  DeviceAlert.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

// Temporary until the rename follows through to Loop
public typealias DeviceAlertHandler = DeviceAlertPresenter

/// Protocol that describes any class that presents Alerts.
public protocol DeviceAlertPresenter: class {
    /// Issue (post) the given alert, according to its trigger schedule.
    func issueAlert(_ alert: DeviceAlert)
    /// Unschedule any pending alerts with the given identifier.
    func removePendingAlert(identifier: DeviceAlert.Identifier)
    /// Remove any alerts currently posted with the given identifier.  It ignores any pending alerts.
    func removeDeliveredAlert(identifier: DeviceAlert.Identifier)
}

/// Protocol that describes something that can deal with a user's response to an alert.
public protocol DeviceAlertResponder: class {
    /// Acknowledge alerts with a given type identifier
    func acknowledgeAlert(typeIdentifier: DeviceAlert.TypeIdentifier) -> Void
}

/// Structure that represents an Alert that is issued from a Device.
public struct DeviceAlert {
    /// Representation of an alert Trigger
    public enum Trigger {
        /// Trigger the alert immediately
        case immediate
        /// Delay triggering the alert by `interval`, but issue it only once.
        case delayed(interval: TimeInterval)
        /// Delay triggering the alert by `repeatInterval`, and repeat at that interval until cancelled or unscheduled.
        case repeating(repeatInterval: TimeInterval)
    }
    /// Content of the alert, either for foreground or background alerts
    public struct Content {
        public let title: String
        public let body: String
        /// Should this alert be deemed "critical" for the User?  Handlers will determine how that is manifested.
        public let isCritical: Bool
        // TODO: when we have more complicated actions.  For now, all we have is "acknowledge".
//        let actions: [UserAlertAction]
        public let acknowledgeActionButtonLabel: String
        public init(title: String, body: String, acknowledgeActionButtonLabel: String, isCritical: Bool = false) {
            self.title = title
            self.body = body
            self.acknowledgeActionButtonLabel = acknowledgeActionButtonLabel
            self.isCritical = isCritical
        }
    }
    public struct Identifier: Hashable {
        /// Unique device manager identifier from whence the alert came, and to which alert acknowledgements should be directed.
        public let managerIdentifier: String
        /// Per-alert-type identifier, for instance to group alert types.  This is the identifier that will be used to acknowledge the alert.
        public let typeIdentifier: TypeIdentifier
        public init(managerIdentifier: String, typeIdentifier: TypeIdentifier) {
            self.managerIdentifier = managerIdentifier
            self.typeIdentifier = typeIdentifier
        }
        /// An opaque value for this tuple for unique identification of the alert across devices.
        public var value: String {
            return "\(managerIdentifier).\(typeIdentifier)"
        }
    }
    /// This type represents a per-alert-type identifier, but not necessarily unique across devices.  Each device may have its own Swift type for this,
    /// so conversion to String is the most convenient, but aliasing the type is helpful because it is not just "any String".
    public typealias TypeIdentifier = String

    /// Alert content to show while app is in the foreground.  If nil, there shall be no alert while app is in the foreground.
    public let foregroundContent: Content?
    /// Alert content to show while app is in the background.  If nil, there shall be no alert while app is in the background.
    public let backgroundContent: Content?
    /// Trigger for the alert.
    public let trigger: Trigger

    /// An alert's "identifier" is a tuple of `managerIdentifier` and `typeIdentifier`.  It's purpose is to uniquely identify an alert so we can
    /// find which device issued it, and send acknowledgment of that alert to the proper device manager.
    public var identifier: Identifier
        
    public init(identifier: Identifier, foregroundContent: Content?, backgroundContent: Content?, trigger: Trigger) {
        self.identifier = identifier
        self.foregroundContent = foregroundContent
        self.backgroundContent = backgroundContent
        self.trigger = trigger
    }
}

// For later:
//public struct UserAlertAction {
//    let identifier: UniqueCommonIdentifier
//    let name: String
//    let isHandledInBackground: Bool // Can this action be handled in the background, or does the app need to be brought up?
//    let destructive: Bool // Should this action be displayed in a way that signifies it is "destructive" (e.g. is the button red?)
//    let deepLinkTarget: String? // The screen to target when the app is brought up. TODO: what type should this be?  A URL/URN or some kind of path makes sense but I'm not sure.
//    let perform: ()->Void
//}
//
//public protocol UserAlertProvider {
//    func listPossibleActions() -> [UserAlert.Action]
//}

