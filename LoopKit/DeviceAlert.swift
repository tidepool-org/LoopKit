//
//  DeviceAlert.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

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
    func acknowledgeAlert(alertIdentifier: DeviceAlert.AlertIdentifier) -> Void
}

/// Structure that represents an Alert that is issued from a Device.
public struct DeviceAlert {
    /// Representation of an alert Trigger
    public enum Trigger: Equatable {
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
        public let alertIdentifier: AlertIdentifier
        public init(managerIdentifier: String, alertIdentifier: AlertIdentifier) {
            self.managerIdentifier = managerIdentifier
            self.alertIdentifier = alertIdentifier
        }
        /// An opaque value for this tuple for unique identification of the alert across devices.
        public var value: String {
            return "\(managerIdentifier).\(alertIdentifier)"
        }
    }
    /// This type represents a per-alert-type identifier, but not necessarily unique across devices.  Each device may have its own Swift type for this,
    /// so conversion to String is the most convenient, but aliasing the type is helpful because it is not just "any String".
    public typealias AlertIdentifier = String

    /// Alert content to show while app is in the foreground.  If nil, there shall be no alert while app is in the foreground.
    public let foregroundContent: Content?
    /// Alert content to show while app is in the background.  If nil, there shall be no alert while app is in the background.
    public let backgroundContent: Content?
    /// Trigger for the alert.
    public let trigger: Trigger

    /// An alert's "identifier" is a tuple of `managerIdentifier` and `alertIdentifier`.  It's purpose is to uniquely identify an alert so we can
    /// find which device issued it, and send acknowledgment of that alert to the proper device manager.
    public let identifier: Identifier

    /// Representation of a "sound" (or other sound-like action, like vibrate) to perform when the alert is issued.
    public enum Sound: Equatable {
        case vibrate
        case silence
        case sound(name: String)
    }
    public let sound: Sound?
    
    public init(identifier: Identifier, foregroundContent: Content?, backgroundContent: Content?, trigger: Trigger, sound: Sound? = nil) {
        self.identifier = identifier
        self.foregroundContent = foregroundContent
        self.backgroundContent = backgroundContent
        self.trigger = trigger
        self.sound = sound
    }
}

public extension DeviceAlert.Sound {
    var filename: String? {
        switch self {
        case .sound(let name): return name
        case .silence, .vibrate: return nil
        }
    }
}

public protocol DeviceAlertSoundVendor {
    // Get the base URL for where to find all the vendor's sounds.  It is under here that all of the sound files should be.
    // Returns nil if the vendor has no sounds.
    func getSoundBaseURL() -> URL?
    // Get all the sounds for this vendor.  Returns an empty array if the vendor has no sounds.
    func getSounds() -> [DeviceAlert.Sound]
}

// MARK: Codable implementations

extension DeviceAlert: Codable {
    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
    public static func decode(from data: Data) throws -> DeviceAlert {
        let decoder = JSONDecoder()
        return try decoder.decode(DeviceAlert.self, from: data)
    }
}

extension DeviceAlert.Content: Codable { }
extension DeviceAlert.Identifier: Codable { }
extension DeviceAlert.Trigger: Codable {
    private enum CodingKeys: String, CodingKey {
      case base, delayInterval, repeatInterval
    }
    private enum Base: String, Codable {
      case immediate, delayed, repeating
    }
    private enum CodingError: Swift.Error { case invalidTriggerValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = try container.decode(Base.self, forKey: .base)
        switch base {
        case .immediate:
            self = .immediate
        case .delayed:
            let delayInterval = try container.decode(TimeInterval.self, forKey: .delayInterval)
            self = .delayed(interval: delayInterval)
        case .repeating:
            let repeatInterval = try container.decode(TimeInterval.self, forKey: .repeatInterval)
            self = .repeating(repeatInterval: repeatInterval)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .immediate:
            try container.encode(Base.immediate, forKey: .base)
        case .delayed(let interval):
            try container.encode(Base.delayed, forKey: .base)
            try container.encode(interval, forKey: .delayInterval)
        case .repeating(let repeatInterval):
            try container.encode(Base.repeating, forKey: .base)
            try container.encode(repeatInterval, forKey: .repeatInterval)
        }
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

