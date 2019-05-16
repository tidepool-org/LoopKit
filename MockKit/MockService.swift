//
//  MockService.swift
//  MockKit
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import LoopKit


public final class MockService: Service {

    public static let managerIdentifier = "MockService"

    public static let localizedTitle = "Simulator"

    public var delegateQueue: DispatchQueue! {
        get {
            return delegate.queue
        }
        set {
            delegate.queue = newValue
        }
    }

    public weak var serviceDelegate: ServiceDelegate? {
        get {
            return delegate.delegate
        }
        set {
            delegate.delegate = newValue
        }
    }

    private let delegate = WeakSynchronizedDelegate<ServiceDelegate>()

    public var remoteData: Bool

    public var logging: Bool

    public var analytics: Bool

    public var history: [String]

    private var dateFormatter = ISO8601DateFormatter()

    public init() {
        self.remoteData = true
        self.logging = true
        self.analytics = true

        self.history = []
    }

    public init?(rawState: RawStateValue) {
        self.remoteData = rawState["remoteData"] as? Bool ?? false
        self.logging = rawState["logging"] as? Bool ?? false
        self.analytics = rawState["analytics"] as? Bool ?? false
        
        self.history = []
    }

    public var rawState: RawStateValue {
        return [
            "remoteData": remoteData,
            "logging": logging,
            "analytics": analytics
        ]
    }

    private func record(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        history.append("\(timestamp): \(message)")
    }

}

extension MockService {

    public var debugDescription: String {
        return """
        ## MockService
        """
    }

}


extension MockService: Analytics {

    // MARK: - UIApplicationDelegate

    public func application(didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any]?) {
        recordAnalytics("applicationDidFinishLaunchingWithOptions; launchOptions: \(launchOptions ?? [:])")
    }

    // MARK: - Screens

    public func didDisplayBolusScreen() {
        recordAnalytics("didDisplayBolusScreen")
    }

    public func didDisplaySettingsScreen() {
        recordAnalytics("didDisplaySettingsScreen")
    }

    public func didDisplayStatusScreen() {
        recordAnalytics("didDisplayStatusScreen")
    }

    // MARK: - Config Events

    public func transmitterTimeDidDrift(_ drift: TimeInterval) {
        recordAnalytics("transmitterTimeDidDrift; drift: \(drift)")
    }

    public func pumpTimeDidDrift(_ drift: TimeInterval) {
        recordAnalytics("pumpTimeDidDrift; drift: \(drift)")
    }

    public func pumpTimeZoneDidChange() {
        recordAnalytics("pumpTimeZoneDidChange")
    }

    public func pumpBatteryWasReplaced() {
        recordAnalytics("pumpBatteryWasReplaced")
    }

    public func reservoirWasRewound() {
        recordAnalytics("reservoirWasRewound")
    }

    public func didChangeBasalRateSchedule() {
        recordAnalytics("didChangeBasalRateSchedule")
    }

    public func didChangeCarbRatioSchedule() {
        recordAnalytics("didChangeCarbRatioSchedule")
    }

    public func didChangeInsulinModel() {
        recordAnalytics("didChangeInsulinModel")
    }

    public func didChangeInsulinSensitivitySchedule() {
        recordAnalytics("didChangeInsulinSensitivitySchedule")
    }

    public func didChangeLoopSettings(from oldValue: LoopSettings, to newValue: LoopSettings) {
        recordAnalytics("didChangeLoopSettings; from: \(oldValue); to: \(newValue)")
    }

    // MARK: - Loop Events

    public func didAddCarbsFromWatch() {
        recordAnalytics("didAddCarbsFromWatch")
    }

    public func didRetryBolus() {
        recordAnalytics("didRetryBolus")
    }

    public func didSetBolusFromWatch(_ units: Double) {
        recordAnalytics("didSetBolusFromWatch; units: \(units)")
    }

    public func didFetchNewCGMData() {
        recordAnalytics("didFetchNewCGMData")
    }

    public func loopDidSucceed() {
        recordAnalytics("loopDidSucceed")
    }

    public func loopDidError() {
        recordAnalytics("loopDidError")
    }

    private func recordAnalytics(_ message: String) {
        if analytics {
            record("[Analytics] \(message)")
        }
    }

}


extension MockService: Logging {

    public func log (_ message: StaticString, subsystem: String, category: String, type: OSLogType, _ args: [CVarArg]) {

        // Since this is only stored in memory, do not worry about public/private qualifiers
        let messageWithoutQualifiers = message.description.replacingOccurrences(of: "%{public}", with: "%").replacingOccurrences(of: "%{private}", with: "%")
        let messageWithArguments = String(format: messageWithoutQualifiers, arguments: args)

        record("[Logging] \(messageWithArguments)")
    }

}


extension MockService: RemoteData {

    public func uploadLoopStatus(insulinOnBoard: InsulinValue?,
                                 carbsOnBoard: CarbValue?,
                                 predictedGlucose: [GlucoseValue]?,
                                 recommendedTempBasal: (recommendation: TempBasalRecommendation, date: Date)?,
                                 recommendedBolus: Double?,
                                 lastTempBasal: DoseEntry?,
                                 lastReservoirValue: ReservoirValue?,
                                 pumpManagerStatus: PumpManagerStatus?,
                                 loopError: Error?) {
        recordRemoteData(["Upload loop status with insulin on board (\(String(describing: insulinOnBoard)))",
            "carbs on board (\(String(describing: carbsOnBoard)))",
            "predicted glucose (\(String(describing: predictedGlucose)))",
            "recommended temp basal (\(String(describing: recommendedTempBasal)))",
            "recommended bolus (\(String(describing: recommendedBolus)))",
            "last temp basal (\(String(describing: lastTempBasal)))",
            "last reservoir value (\(String(describing: lastReservoirValue)))",
            "pump manager status (\(String(describing: pumpManagerStatus)))",
            "and loop error (\(String(describing: loopError)))"].joined(separator: "; "))
    }

    public func upload(pumpStatus: PumpStatus?, deviceName: String?, firmwareVersion: String?) {
        recordRemoteData("Upload pump status (\(String(describing: pumpStatus))) with device name (\(String(describing: deviceName))) and firmware version (\(String(describing: firmwareVersion)))")
    }

    public func upload(glucoseValues values: [GlucoseValue], sensorState: SensorDisplayable?) {
        recordRemoteData("Upload gllucose values (\(values)) with sensor state (\(String(describing: sensorState)))")
    }

    public func upload(pumpEvents events: [PersistedPumpEvent], fromSource source: String, completion: @escaping (Result<[URL], Error>) -> Void) {
        recordRemoteData("Upload pump events (\(events)) from source (\(source))")
        completion(Result.success([]))
    }

    public func upload(carbEntries entries: [StoredCarbEntry], completion: @escaping (_ entries: [StoredCarbEntry]) -> Void) {
        recordRemoteData("Upload carb entries (\(entries))")
        completion(entries)
    }

    public func delete(carbEntries entries: [DeletedCarbEntry], completion: @escaping (_ entries: [DeletedCarbEntry]) -> Void) {
        recordRemoteData("Delete carb entries (\(entries))")
        completion(entries)
    }

    private func recordRemoteData(_ message: String) {
        if remoteData {
            record("[RemoteData] \(message)")
        }
    }

}
