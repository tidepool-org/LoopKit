//
//  MockCGMManagerSettingsViewModel.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import MockKit

class MockCGMManagerSettingsViewModel: ObservableObject {
    
    let cgmManager: MockCGMManager
    
    var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable
    
//    @Published var isDeliverySuspended: Bool {
//        didSet {
//            transitioningSuspendResumeInsulinDelivery = false
//            basalDeliveryState = pumpManager.status.basalDeliveryState
//        }
//    }
//
//    @Published var transitioningSuspendResumeInsulinDelivery = false
//
//    @Published var suspendedAtString: String? = nil
    
//    var suspendResumeInsulinDeliveryLabel: String {
//        if isDeliverySuspended {
//            return "Tap to Resume Insulin Delivery"
//        } else {
//            return "Suspend Insulin Delivery"
//        }
//    }
//
    static private let dateTimeFormatter: DateFormatter = {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .short
        return timeFormatter
    }()
//
//    static private let shortTimeFormatter: DateFormatter = {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .none
//        formatter.timeStyle = .short
//        return formatter
//    }()
//
    var sensorInsertionDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(sensorInsertionInterval))
    }

    var sensorExpirationRemaining = TimeInterval(days: 5.0)
    var sensorInsertionInterval = TimeInterval(days: -5.0)
    var sensorExpirationPercentComplete: Double = 0.25

    var sensorExpirationDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(sensorExpirationRemaining))
    }
    
    @Published private(set) var lastGlucoseValueFormatted: String?
//
//    var pumpTimeString: String {
//        Self.shortTimeFormatter.string(from: Date())
//    }
//
//    @Published var basalDeliveryState: PumpManagerStatus.BasalDeliveryState? {
//        didSet {
//            setSuspenededAtString()
//        }
//    }
//
//    @Published var basalDeliveryRate: Double?
//
//    @Published var presentDeliveryWarning: Bool?
//
//    var isScheduledBasal: Bool {
//        switch basalDeliveryState {
//        case .active, .initiatingTempBasal:
//            return true
//        case .tempBasal, .cancelingTempBasal, .suspending, .suspended, .resuming, .none:
//            return false
//        }
//    }
//
//    var isTempBasal: Bool {
//        switch basalDeliveryState {
//        case .tempBasal, .cancelingTempBasal:
//            return true
//        case .active, .initiatingTempBasal, .suspending, .suspended, .resuming, .none:
//            return false
//        }
//    }
    
    init(cgmManager: MockCGMManager, displayGlucoseUnitObservable: DisplayGlucoseUnitObservable) {
        self.cgmManager = cgmManager
        self.displayGlucoseUnitObservable = displayGlucoseUnitObservable
        
//        isDeliverySuspended = pumpManager.status.basalDeliveryState?.isSuspended == true
//        basalDeliveryState = pumpManager.status.basalDeliveryState
//        basalDeliveryRate = pumpManager.state.basalDeliveryRate(at: Date())
//        setSuspenededAtString()
        
        cgmManager.addStatusObserver(self, queue: .main)
    }
    
//    private func setSuspenededAtString() {
//        switch basalDeliveryState {
//        case .suspended(let suspendedAt):
//            let formatter = DateFormatter()
//            formatter.dateStyle = .medium
//            formatter.timeStyle = .short
//            formatter.doesRelativeDateFormatting = true
//            suspendedAtString = formatter.string(from: suspendedAt)
//        default:
//            suspendedAtString = nil
//        }
//    }
//
//    func resumeDelivery(completion: @escaping (Error?) -> Void) {
//        transitioningSuspendResumeInsulinDelivery = true
//        pumpManager.resumeDelivery() { [weak self] error in
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                if error == nil {
//                    self?.isDeliverySuspended = false
//                }
//                completion(error)
//            }
//        }
//    }
//
//    func suspendDelivery(completion: @escaping (Error?) -> Void) {
//        transitioningSuspendResumeInsulinDelivery = true
//        pumpManager.suspendDelivery() { [weak self] error in
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                if error == nil {
//                    self?.isDeliverySuspended = true
//                }
//                completion(error)
//            }
//        }
//    }
}

extension MockCGMManagerSettingsViewModel: CGMManagerStatusObserver {
    func cgmManager(_ manager: LoopKit.CGMManager, didUpdate status: LoopKit.CGMManagerStatus) {
//        lastGlucoseValueFormatted = String(format: "%@ %@", , displayGlucoseUnitObservable.displayGlucoseUnit.shortLocalizedUnitString())
    }
}
