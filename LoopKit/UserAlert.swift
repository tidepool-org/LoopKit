//
//  UserAlert.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

/// Protocol that describes any class that handles Alert posting.
public protocol UserAlertHandler: class {
    /// Schedule the given alert for posting.
    func scheduleAlert(_ alert: UserAlert)
    /// Unschedule any pending alerts with the given identifier.
    func unscheduleAlert(managerIdentifier: String, typeIdentifier: UserAlert.TypeIdentifier)
    /// Remove any alerts currently posted with the given identifier.  It ignores any pending alerts.
    func cancelAlert(managerIdentifier: String, typeIdentifier: UserAlert.TypeIdentifier)
}

/// Protocol that describes something that can deal with a user's response to an alert.
public protocol UserAlertResponder {
    /// Acknowledge alerts with a given type identifier
    func acknowledgeAlert(typeIdentifier: UserAlert.TypeIdentifier) -> Void
}

/// Structure that represents an Alert that needs to be shown to the User.
public struct UserAlert {
    /// Representation of an alert Trigger
    public enum Trigger {
        /// Trigger the alert immediately
        case immediate
        /// Delay triggering the alert by `interval`, but issue it only once.
        case delayed(interval: TimeInterval)
        /// Delay triggering the alert by `repeatInterval`, and repeat at that interval until cancelled or unscheduled.
        case repeating(repeatInterval: TimeInterval)
    }
    public struct Content {
        public let title: String
        public let body: String
        public let isCritical: Bool
        // TODO: when we have more complicated actions.  For now, all we have is "acknowledge".
//        let actions: [UserAlertAction]
        public let acknowledgeAction: String
        public init(title: String, body: String, acknowledgeAction: String, isCritical: Bool = false) {
            self.title = title
            self.body = body
            self.acknowledgeAction = acknowledgeAction
            self.isCritical = isCritical
        }
    }
    public typealias TypeIdentifier = String
    public typealias AcknowledgeCompletion = (TypeIdentifier) -> Void

    /// Unique device manager identifier from whence the alert came, and to which alert acknowledgements should be directed.
    public let managerIdentifier: String
    /// Per-alert unique identifier, for instance to group alert types.  This is the identifier that will be used to acknowledge the alert.
    public let typeIdentifier: TypeIdentifier
    /// Alert content to show while app is in the foreground.  If nil, there shall be no alert while app is in the foreground.
    public let foregroundContent: Content?
    /// Alert content to show while app is in the background.  If nil, there shall be no alert while app is in the background.
    public let backgroundContent: Content?
    /// Trigger for the alert.
    public let trigger: Trigger
    /// A completion block to call once the user has "officially" acknowledged the alert.
    public let acknowledgeCompletion: AcknowledgeCompletion?

    public var identifier: String {
        return UserAlert.getIdentifier(managerIdentifier: managerIdentifier, typeIdentifier: typeIdentifier)
    }
    
    public static func getIdentifier(managerIdentifier: String, typeIdentifier: TypeIdentifier) -> String {
        return "\(managerIdentifier).\(typeIdentifier)"
    }
    
    public init(managerIdentifier: String, typeIdentifier: TypeIdentifier, foregroundContent: Content?, backgroundContent: Content?, trigger: Trigger, acknowledgeCompletion: AcknowledgeCompletion?) {
        self.managerIdentifier = managerIdentifier
        self.typeIdentifier = typeIdentifier
        self.foregroundContent = foregroundContent
        self.backgroundContent = backgroundContent
        self.trigger = trigger
        self.acknowledgeCompletion = acknowledgeCompletion
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

