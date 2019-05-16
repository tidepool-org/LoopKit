//
//  Analytics.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/11/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


public protocol Analytics {

    // MARK: - UIApplicationDelegate

    func application(didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any]?)

    // MARK: - Screens

    func didDisplayBolusScreen()

    func didDisplaySettingsScreen()

    func didDisplayStatusScreen()

    // MARK: - Config Events

    func transmitterTimeDidDrift(_ drift: TimeInterval)

    func pumpTimeDidDrift(_ drift: TimeInterval)

    func pumpTimeZoneDidChange()

    func pumpBatteryWasReplaced()

    func reservoirWasRewound()

    func didChangeBasalRateSchedule()

    func didChangeCarbRatioSchedule()

    func didChangeInsulinModel()

    func didChangeInsulinSensitivitySchedule()

    func didChangeLoopSettings(from oldValue: LoopSettings, to newValue: LoopSettings)

    // MARK: - Loop Events

    func didAddCarbsFromWatch()

    func didRetryBolus()

    func didSetBolusFromWatch(_ units: Double)

    func didFetchNewCGMData()

    func loopDidSucceed()

    func loopDidError()

}
