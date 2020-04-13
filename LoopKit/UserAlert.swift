//
//  UserAlert.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol UserAlertHandler: class {
    func scheduleAlert(_ alert: UserAlert)
    func unscheduleAlert(identifier: String)
    func cancelAlert(identifier: String)
}

public protocol UserAlertResponder: class {
    /// Acknowledges the alert identified
    ///
    /// - Parameters:
    ///   - alertID: identifier of the alert to acknowledge
    func acknowledgeAlert(alertID: Int) -> Void
}

public struct UserAlert {
    public struct Trigger {
        public let timeInterval: TimeInterval
        public let repeats: Bool
        public init(timeInterval: TimeInterval, repeats: Bool) {
            self.timeInterval = timeInterval
            self.repeats = repeats
        }
    }
    public struct Content {
        public let title: String
        public let body: String
        public let isCritical: Bool
        // TODO: when we have more complicated actions
//        let actions: [UserAlertAction]
        public let dismissAction: String
        public init(title: String, body: String, dismissAction: String, isCritical: Bool = false) {
            self.title = title
            self.body = body
            self.dismissAction = dismissAction
            self.isCritical = isCritical
        }
    }
    public let managerIdentifier: String  // Unique device manager identifier to direct responses to
    public let alertTypeId: Int   // Per-alert unique identifier to group alerts into, by type (TODO: is Int the right type?)
    public let foregroundContent: Content
    public let backgroundContent: Content? // If nil, it implies both foreground and background content is the same, so use `foregroundContent`
    /// Specify nil to deliver the notification right away
    public let trigger: Trigger?
    public let acknowledgeCompletion: ((UserAlert)->Void)?

    public var identifier: String {
        return UserAlert.getIdentifier(managerIdentifier: managerIdentifier, alertTypeId: alertTypeId)
    }
    
    public static func getIdentifier(managerIdentifier: String, alertTypeId: Int) -> String {
        return "\(managerIdentifier).\(alertTypeId)"
    }
    
    public init(managerIdentifier: String, alertTypeId: Int, foregroundContent: Content, backgroundContent: Content?, trigger: Trigger?, acknowledgeCompletion: ((UserAlert) -> Void)?) {
        self.managerIdentifier = managerIdentifier
        self.alertTypeId = alertTypeId
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

