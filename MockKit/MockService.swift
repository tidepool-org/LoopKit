//
//  MockService.swift
//  MockKit
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import Foundation
import LoopKit

public final class MockService: Service {
    public static let serviceIdentifier = "MockService"
    
    public var pluginIdentifier: String { Self.serviceIdentifier }
    
    public static let localizedTitle = "Simulator"
    
    public weak var stateDelegate: StatefulPluggableDelegate?
    
    public weak var serviceDelegate: ServiceDelegate?

    public weak var remoteDataServiceDelegate: RemoteDataServiceDelegate?

    public var remoteData: Bool
    
    public var logging: Bool
    
    public var analytics: Bool
        
    public let maxHistoryItems = 1000
    
    private var lockedHistory = Locked<[String]>([])
    
    public var history: [String] {
        lockedHistory.value
    }
    
    private var dateFormatter = ISO8601DateFormatter()
    
    public init() {
        self.remoteData = true
        self.logging = true
        self.analytics = true
    }
    
    public init?(rawState: RawStateValue) {
        self.remoteData = rawState["remoteData"] as? Bool ?? false
        self.logging = rawState["logging"] as? Bool ?? false
        self.analytics = rawState["analytics"] as? Bool ?? false
    }
    
    public var rawState: RawStateValue {
        var rawValue: RawStateValue = [:]
        rawValue["remoteData"] = remoteData
        rawValue["logging"] = logging
        rawValue["analytics"] = analytics
        return rawValue
    }
    
    public let isOnboarded = true   // No distinction between created and onboarded
    
    public func completeCreate() {}
    
    public func completeUpdate() {
        stateDelegate?.pluginDidUpdateState(self)
    }
    
    public func completeDelete() {
        stateDelegate?.pluginWantsDeletion(self)
    }
    
    public func clearHistory() {
        lockedHistory.value = []
    }
    
    private func record(_ message: String) {
        let timestamp = self.dateFormatter.string(from: Date())
        lockedHistory.mutate { history in
            history.append("\(timestamp): \(message)")
            if history.count > self.maxHistoryItems {
                history.removeFirst(history.count - self.maxHistoryItems)
            }
        }
    }
    
}

extension MockService: AnalyticsService {
    public func recordIdentify(_ property: String, array: [String]) {
        record("[AnalyticsService] Identify: \(property) \(array)")
    }

    public func recordAnalyticsEvent(_ name: String, withProperties properties: [AnyHashable: Any]?, outOfSession: Bool) {
        if analytics {
            record("[AnalyticsService] \(name) \(String(describing: properties)) \(outOfSession)")
        }
    }

    public func recordIdentify(_ property: String, value: String) {
        record("[AnalyticsService] Identify: \(property) \(value)")
    }
}

extension MockService: LoggingService {
    
    public func log(_ message: StaticString, subsystem: String, category: String, type: OSLogType, _ args: [CVarArg]) {
        if logging {
            // Since this is only stored in memory, do not worry about public/private qualifiers
            let messageWithoutQualifiers = message.description.replacingOccurrences(of: "%{public}", with: "%").replacingOccurrences(of: "%{private}", with: "%")
            let messageWithArguments = String(format: messageWithoutQualifiers, arguments: args)
            
            record("[LoggingService] \(messageWithArguments)")
        }
    }
    
}

extension MockService: RemoteDataService {
    public func uploadTemporaryOverrideData(updated: [TemporaryScheduleOverride], deleted: [TemporaryScheduleOverride]) async throws {
        if remoteData {
            record("[RemoteDataService] Upload temporary override data (updated: \(updated.count), deleted: \(deleted.count))")
        }
    }
    
    public func uploadAlertData(_ stored: [SyncAlertObject]) async throws {
        if remoteData {
            record("[RemoteDataService] Upload alert data (stored: \(stored.count))")
        }
    }

    public func uploadCarbData(created: [SyncCarbObject], updated: [SyncCarbObject], deleted: [SyncCarbObject]) async throws {
        if remoteData {
            record("[RemoteDataService] Upload carb data (created: \(created.count), updated: \(updated.count), deleted: \(deleted.count))")
        }
    }
    
    public func uploadDoseData(created: [DoseEntry], deleted: [DoseEntry]) async throws {
        if remoteData {
            record("[RemoteDataService] Upload dose data (created: \(created.count), deleted: \(deleted.count))")
        }
    }

    public func uploadDosingDecisionData(_ stored: [StoredDosingDecision]) async throws {
        if remoteData {
            let warned = stored.filter { !$0.warnings.isEmpty }
            let errored = stored.filter { !$0.errors.isEmpty }
            record("[RemoteDataService] Upload dosing decision data (stored: \(stored.count), warned: \(warned.count), errored: \(errored.count))")
        }
    }
    
    public func uploadGlucoseData(_ stored: [StoredGlucoseSample]) async throws {
        if remoteData {
            record("[RemoteDataService] Upload glucose data (stored: \(stored.count))")
        }
    }
    
    public func uploadPumpEventData(_ stored: [PersistedPumpEvent]) async throws {
        if remoteData {
            record("[RemoteDataService] Upload pump event data (stored: \(stored.count))")
        }
    }
    
    public func uploadSettingsData(_ stored: [StoredSettings]) async throws {
        if remoteData {
            record("[RemoteDataService] Upload settings data (stored: \(stored.count))")
        }
    }

    public func uploadCgmEventData(_ stored: [PersistedCgmEvent]) async throws {
        if remoteData {
            record("[RemoteDataService] Upload cgm event data (stored: \(stored.count))")
        }
    }

    public func remoteNotificationWasReceived(_ notification: [String: AnyObject]) async throws {
    }
}
